import Foundation
import Crypto
import Vapor

// MARK: - Service Protocol

/// Protocol for generating deterministic, normalized cache keys for rules generation
protocol CacheKeyGeneratorServiceInterface: Sendable {
    /// Returns a service instance for the given request
    func `for`(_ request: Request) -> CacheKeyGeneratorServiceInterface

    /// Generates a cache key for rules generation requests
    func generateRulesKey(for gameTitle: String) -> String

    /// Validates that a cache key is properly formatted
    func isValidCacheKey(_ key: String) -> Bool

    /// Extracts the cache type from a cache key
    func extractCacheType(from key: String) -> AICacheType?

    /// Generates a human-readable description of what a cache key represents
    func describeKey(_ key: String) -> String
}

// MARK: - Default Implementation

/// Default implementation of cache key generation service
struct DefaultCacheKeyGeneratorService: CacheKeyGeneratorServiceInterface {
    
    private let app: Application?
    private let logger: Logger?
    
    // MARK: - Initialization
    
    init(app: Application? = nil) {
        self.app = app
        self.logger = app?.logger
    }
    
    // MARK: - Service Pattern
    
    func `for`(_ request: Request) -> CacheKeyGeneratorServiceInterface {
        return DefaultCacheKeyGeneratorService(app: request.application)
    }
    
    // MARK: - Public Methods
    
    /// Generates a cache key for rules generation requests
    func generateRulesKey(for gameTitle: String) -> String {
        let normalizedTitle = normalizeGameTitle(gameTitle)
        let keyData = "rules:\(normalizedTitle)".data(using: .utf8)!

        logger?.debug("Generated rules cache key", metadata: [
            "original_title": .string(gameTitle),
            "normalized_title": .string(normalizedTitle)
        ])

        return generateHashedKey(from: keyData, prefix: "rules")
    }
    
    /// Validates that a cache key is properly formatted
    func isValidCacheKey(_ key: String) -> Bool {
        // Check basic format: prefix_hash
        let components = key.split(separator: "_")
        guard components.count == 2 else { return false }

        let prefix = String(components[0])
        let hash = String(components[1])

        // Validate prefix (only rules supported)
        guard prefix == "rules" else { return false }

        // Validate hash (32 hex characters)
        guard hash.count == 32 else { return false }
        guard hash.allSatisfy({ $0.isHexDigit }) else { return false }

        return true
    }
    
    /// Extracts the cache type from a cache key
    func extractCacheType(from key: String) -> AICacheType? {
        guard isValidCacheKey(key) else { return nil }
        return .rulesGeneration
    }
    
    /// Generates a human-readable description of what a cache key represents
    func describeKey(_ key: String) -> String {
        guard isValidCacheKey(key) else {
            return "Invalid cache key: \(key)"
        }

        let components = key.split(separator: "_")
        let hash = String(components[1])
        return "Rules generation cache key (hash: \(hash))"
    }
    
    // MARK: - Private Normalization Methods
    
    /// Normalizes a game title for consistent key generation
    private func normalizeGameTitle(_ gameTitle: String) -> String {
        return gameTitle
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current) // Remove accents
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression) // Remove special chars
            .replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression) // Replace spaces with underscores
            .replacingOccurrences(of: "_+", with: "_", options: .regularExpression) // Collapse multiple underscores
            .trimmingCharacters(in: CharacterSet(charactersIn: "_")) // Remove leading/trailing underscores
    }
    
    /// Generates a SHA256-based hash key with prefix
    private func generateHashedKey(from data: Data, prefix: String) -> String {
        let hash = SHA256.hash(data: data)
        let hashBytes = withUnsafeBytes(of: hash) { bytes in
            Array(bytes)
        }
        let hashString = hashBytes.map { String(format: "%02x", $0) }.joined()
        
        // Use first 32 characters of hash for better collision resistance
        let truncatedHash = String(hashString.prefix(32))
        return "\(prefix)_\(truncatedHash)"
    }
}

// MARK: - Service Registration

extension Application.Services {
    var cacheKeyGenerator: Application.Service<CacheKeyGeneratorServiceInterface> {
        .init(application: application)
    }
}

extension Request.Services {
    var cacheKeyGenerator: CacheKeyGeneratorServiceInterface {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.cacheKeyGeneratorService.for(request)
    }
}


// MARK: - Character Extension

private extension Character {
    /// Checks if the character is a valid hexadecimal digit
    var isHexDigit: Bool {
        return self.isASCII && (
            (self >= "0" && self <= "9") ||
            (self >= "a" && self <= "f") ||
            (self >= "A" && self <= "F")
        )
    }
}
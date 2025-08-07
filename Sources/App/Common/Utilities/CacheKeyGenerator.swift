import Foundation
import Crypto

/// Utility for generating deterministic, normalized cache keys from AI operation inputs
/// This ensures consistent caching for equivalent requests regardless of input variations
struct CacheKeyGenerator {
    
    // MARK: - Public Methods
    
    /// Generates a cache key for rules generation requests
    /// - Parameter gameTitle: The raw game title from user input
    /// - Returns: A deterministic cache key
    static func generateRulesKey(for gameTitle: String) -> String {
        let normalizedTitle = normalizeGameTitle(gameTitle)
        let keyData = "rules:\(normalizedTitle)".data(using: .utf8)!
        return generateHashedKey(from: keyData, prefix: "rules")
    }
    
    /// Generates a cache key for image analysis requests
    /// - Parameter imageData: The image data to analyze
    /// - Returns: A deterministic cache key based on image content
    static func generateImageKey(for imageData: Data) -> String {
        let keyData = imageData
        return generateHashedKey(from: keyData, prefix: "image")
    }
    
    /// Generates a cache key for box photo analysis with additional context
    /// - Parameters:
    ///   - imageData: The image data
    ///   - context: Optional context string (e.g., "box_photo")
    /// - Returns: A deterministic cache key
    static func generateBoxPhotoKey(for imageData: Data, context: String = "box") -> String {
        let contextData = "image_analysis:\(context)".data(using: .utf8)!
        let combinedData = contextData + imageData
        return generateHashedKey(from: combinedData, prefix: "box")
    }
    
    // MARK: - Private Normalization Methods
    
    /// Normalizes a game title for consistent key generation
    /// - Parameter gameTitle: The raw game title
    /// - Returns: Normalized title suitable for cache key generation
    private static func normalizeGameTitle(_ gameTitle: String) -> String {
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
    /// - Parameters:
    ///   - data: The data to hash
    ///   - prefix: A prefix to identify the cache type
    /// - Returns: A hashed key string with prefix
    private static func generateHashedKey(from data: Data, prefix: String) -> String {
        let hash = SHA256.hash(data: data)
        let hashBytes = withUnsafeBytes(of: hash) { bytes in
            Array(bytes)
        }
        let hashString = hashBytes.map { String(format: "%02x", $0) }.joined()
        
        // Use first 16 characters of hash for reasonable key length
        let truncatedHash = String(hashString.prefix(16))
        return "\(prefix)_\(truncatedHash)"
    }
    
    // MARK: - Validation Methods
    
    /// Validates that a cache key is properly formatted
    /// - Parameter key: The cache key to validate
    /// - Returns: true if the key is valid, false otherwise
    static func isValidCacheKey(_ key: String) -> Bool {
        // Check basic format: prefix_hash
        let components = key.split(separator: "_")
        guard components.count == 2 else { return false }
        
        let prefix = String(components[0])
        let hash = String(components[1])
        
        // Validate prefix
        let validPrefixes = ["rules", "image", "box"]
        guard validPrefixes.contains(prefix) else { return false }
        
        // Validate hash (16 hex characters)
        guard hash.count == 16 else { return false }
        guard hash.allSatisfy({ $0.isHexDigit }) else { return false }
        
        return true
    }
    
    /// Extracts the cache type from a cache key
    /// - Parameter key: The cache key
    /// - Returns: The cache type if extractable, nil otherwise
    static func extractCacheType(from key: String) -> AICacheType? {
        guard isValidCacheKey(key) else { return nil }
        
        let prefix = String(key.split(separator: "_").first ?? "")
        switch prefix {
        case "rules":
            return .rulesGeneration
        case "image", "box":
            return .imageAnalysis
        default:
            return nil
        }
    }
    
    // MARK: - Debug Helpers
    
    /// Generates a human-readable description of what a cache key represents
    /// - Parameter key: The cache key
    /// - Returns: A description string for logging/debugging
    static func describeKey(_ key: String) -> String {
        guard isValidCacheKey(key) else {
            return "Invalid cache key: \(key)"
        }
        
        let components = key.split(separator: "_")
        let prefix = String(components[0])
        let hash = String(components[1])
        
        switch prefix {
        case "rules":
            return "Rules generation cache key (hash: \(hash))"
        case "image":
            return "Image analysis cache key (hash: \(hash))"
        case "box":
            return "Box photo analysis cache key (hash: \(hash))"
        default:
            return "Unknown cache type: \(prefix) (hash: \(hash))"
        }
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
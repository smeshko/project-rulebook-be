import Foundation
import Vapor

/// Protocol defining a general-purpose cache service interface
public protocol CacheService: Sendable {
    
    /// Retrieves a cached value for the given key and decodes it to the specified type
    /// - Parameters:
    ///   - key: The cache key to look up
    ///   - type: The type to decode the cached value to
    /// - Returns: The cached value if found and successfully decoded, nil otherwise
    func get<T: Codable>(_ key: String, as type: T.Type) async throws -> T?
    
    /// Stores a value in the cache with optional TTL
    /// - Parameters:
    ///   - key: The cache key to store under
    ///   - value: The value to cache (must be Codable)
    ///   - ttl: Optional time to live in seconds
    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval?) async throws
    
    /// Removes a specific key from the cache
    /// - Parameter key: The cache key to remove
    func delete(_ key: String) async throws
    
    /// Clears all entries from the cache
    func flush() async throws
    
    /// Checks if a key exists in the cache
    /// - Parameter key: The cache key to check
    /// - Returns: true if the key exists, false otherwise
    func exists(_ key: String) async throws -> Bool
}

// MARK: - Cache Error Types

/// Errors that can occur during cache operations
public enum CacheError: Error, LocalizedError {
    case retrievalFailed(Error)
    case storageFailed(Error)
    case deletionFailed(Error)
    case flushFailed(Error)
    case queryFailed(Error)
    case operationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .retrievalFailed(let error):
            return "Cache retrieval failed: \(error.localizedDescription)"
        case .storageFailed(let error):
            return "Cache storage failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Cache deletion failed: \(error.localizedDescription)"
        case .flushFailed(let error):
            return "Cache flush failed: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Cache query failed: \(error.localizedDescription)"
        case .operationFailed(let error):
            return "Cache operation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Import existing CacheStatistics type
// CacheStatistics is already defined in Models/CacheStatistics.swift

// MARK: - Service Registration Extensions

extension Application.Services {
    var cache: Application.Service<CacheService> {
        .init(application: application)
    }
}

extension Request.Services {
    var cache: CacheService {
        // TODO: Implement proper service registration for CacheService
        // For now, return a placeholder - this will be implemented in service registry
        fatalError("CacheService not yet registered in service cache")
    }
}
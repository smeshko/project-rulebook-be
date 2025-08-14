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

// MARK: - Cache Error Types (moved to Entities/Errors/CacheError.swift)

// MARK: - Import existing CacheStatistics type
// CacheStatistics is already defined in Models/CacheStatistics.swift

// MARK: - Service Registration Extensions

extension Application.Services {
    var cache: Application.Service<CacheService> {
        .init(application: application)
    }
}

// MARK: - Service Registration (TODO: Complete in next phase)
// extension Request.Services {
//     var cache: CacheService {
//         // TODO: Implement proper service registration for CacheService
//         // This will be completed when integrating with the service registry
//     }
// }
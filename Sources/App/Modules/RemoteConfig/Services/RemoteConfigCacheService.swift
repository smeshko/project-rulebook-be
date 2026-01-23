import Vapor
import Foundation

/// Cache service for remote configuration with 5-minute TTL.
///
/// Uses the application's CacheService (Redis in production, in-memory for testing)
/// to cache the full configuration response, invalidating on any modifications.
final class RemoteConfigCacheService: @unchecked Sendable {
    private let cacheService: CacheService
    private let logger: Logger

    /// Cache key for the full configuration response.
    static let cacheKey = "remote_config:all"

    /// TTL for cached configuration: 5 minutes (300 seconds).
    static let cacheTTL: TimeInterval = 300

    init(cacheService: CacheService, logger: Logger) {
        self.cacheService = cacheService
        self.logger = logger
    }

    /// Retrieves the cached configuration response if available.
    ///
    /// - Returns: The cached response or nil if not cached or expired.
    func getCachedConfig() async -> RemoteConfig.Get.Response? {
        do {
            let cached = try await cacheService.get(Self.cacheKey, as: RemoteConfig.Get.Response.self)
            if cached != nil {
                logger.debug("Remote config cache hit")
            }
            return cached
        } catch {
            logger.warning("Remote config cache get failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            return nil
        }
    }

    /// Caches the configuration response with 5-minute TTL.
    ///
    /// - Parameter response: The configuration response to cache.
    func setCachedConfig(_ response: RemoteConfig.Get.Response) async {
        do {
            try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
            logger.debug("Remote config cached", metadata: [
                "ttl_seconds": .string("\(Int(Self.cacheTTL))")
            ])
        } catch {
            logger.error("Remote config cache set failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }

    /// Invalidates the cached configuration.
    ///
    /// Call this after any POST, PATCH, or DELETE operation on config values.
    func invalidateCache() async {
        do {
            try await cacheService.delete(Self.cacheKey)
            logger.info("Remote config cache invalidated")
        } catch {
            logger.warning("Remote config cache invalidation failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

// MARK: - Request Extension

extension Request {
    /// Access to the remote config cache service.
    var remoteConfigCache: RemoteConfigCacheService {
        RemoteConfigCacheService(
            cacheService: application.cacheService,
            logger: logger
        )
    }
}

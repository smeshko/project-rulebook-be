import Vapor

protocol RemoteConfigCacheService: Sendable {
    func getConfig(using repository: any RemoteConfigRepository) async throws -> RemoteConfig.Get.Response
    func invalidateCache() async throws
}

final class DefaultRemoteConfigCacheService: RemoteConfigCacheService, @unchecked Sendable {

    private static let cacheKey = "remote_config:all"
    private static let ttlSeconds: TimeInterval = 300 // 5 minutes

    private let cacheService: CacheService
    private let logger: Logger

    init(cacheService: CacheService, logger: Logger) {
        self.cacheService = cacheService
        self.logger = logger
    }

    func getConfig(using repository: any RemoteConfigRepository) async throws -> RemoteConfig.Get.Response {
        // Try to get from cache first (best-effort - Redis failures shouldn't break the endpoint)
        do {
            if let cached = try await cacheService.get(Self.cacheKey, as: RemoteConfig.Get.Response.self) {
                logger.debug("Remote config cache hit")
                return cached
            }
        } catch {
            logger.warning("Remote config cache read failed, falling back to database: \(error)")
        }

        // Cache miss or cache error - fetch from database
        logger.debug("Remote config cache miss, fetching from database")
        let configs = try await repository.all()
        let response = configs.toGetResponse()

        // Store in cache (best-effort - don't fail if Redis is down)
        do {
            try await cacheService.set(Self.cacheKey, value: response, ttl: Self.ttlSeconds)
        } catch {
            logger.warning("Remote config cache write failed: \(error)")
        }

        return response
    }

    func invalidateCache() async throws {
        logger.debug("Invalidating remote config cache")
        do {
            try await cacheService.delete(Self.cacheKey)
        } catch {
            logger.warning("Remote config cache invalidation failed: \(error)")
            // Don't rethrow - cache invalidation is best-effort
        }
    }
}

extension Application {
    var remoteConfigCacheService: RemoteConfigCacheService {
        get { serviceStorage.remoteConfigCacheService! }
        set { serviceStorage.remoteConfigCacheService = newValue }
    }
}

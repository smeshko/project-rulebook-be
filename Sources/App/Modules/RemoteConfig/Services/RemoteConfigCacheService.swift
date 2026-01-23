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
        // Try to get from cache first
        if let cached = try await cacheService.get(Self.cacheKey, as: RemoteConfig.Get.Response.self) {
            logger.debug("Remote config cache hit")
            return cached
        }

        // Cache miss - fetch from database
        logger.debug("Remote config cache miss, fetching from database")
        let configs = try await repository.all()
        let response = configs.toGetResponse()

        // Store in cache
        try await cacheService.set(Self.cacheKey, value: response, ttl: Self.ttlSeconds)

        return response
    }

    func invalidateCache() async throws {
        logger.debug("Invalidating remote config cache")
        try await cacheService.delete(Self.cacheKey)
    }
}

extension Application {
    var remoteConfigCacheService: RemoteConfigCacheService {
        get { serviceStorage.remoteConfigCacheService! }
        set { serviceStorage.remoteConfigCacheService = newValue }
    }
}

@testable import App
import Vapor

final class MockRemoteConfigCacheService: RemoteConfigCacheService, @unchecked Sendable {

    private var cachedResponse: RemoteConfig.Get.Response?
    private(set) var getCacheCallCount = 0
    private(set) var invalidateCacheCallCount = 0

    init() {}

    func getConfig(using repository: any RemoteConfigRepository) async throws -> RemoteConfig.Get.Response {
        getCacheCallCount += 1

        // If we have a cached response, return it
        if let cached = cachedResponse {
            return cached
        }

        // Otherwise fetch from repository
        let configs = try await repository.all()
        let response = configs.toGetResponse()
        cachedResponse = response
        return response
    }

    func invalidateCache() async throws {
        invalidateCacheCallCount += 1
        cachedResponse = nil
    }

    func reset() {
        cachedResponse = nil
        getCacheCallCount = 0
        invalidateCacheCallCount = 0
    }
}

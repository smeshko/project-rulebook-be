@testable import App
import Vapor

final class MockConfigCacheService: ConfigCacheServiceProtocol, @unchecked Sendable {
    private var storage: RemoteConfig.Response?
    private(set) var getAllCallCount = 0
    private(set) var setCallCount = 0
    private(set) var invalidateCallCount = 0

    func getAll() async throws -> RemoteConfig.Response? {
        getAllCallCount += 1
        return storage
    }

    func set(_ config: RemoteConfig.Response) async throws {
        setCallCount += 1
        storage = config
    }

    func invalidate() async throws {
        invalidateCallCount += 1
        storage = nil
    }

    func reset() {
        getAllCallCount = 0
        setCallCount = 0
        invalidateCallCount = 0
        storage = nil
    }
}

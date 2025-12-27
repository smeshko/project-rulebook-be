@testable import App
import Vapor

final class MockConfigCacheService: ConfigCacheServiceProtocol, @unchecked Sendable {
    private var storage: RemoteConfig.Response?

    func getAll() async throws -> RemoteConfig.Response? {
        return storage
    }

    func set(_ config: RemoteConfig.Response) async throws {
        storage = config
    }

    func invalidate() async throws {
        storage = nil
    }
}

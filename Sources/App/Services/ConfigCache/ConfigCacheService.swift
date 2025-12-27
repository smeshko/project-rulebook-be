import Foundation
@preconcurrency import Redis
import Vapor

protocol ConfigCacheServiceProtocol: Sendable {
    func getAll() async throws -> RemoteConfig.Response?
    func set(_ config: RemoteConfig.Response) async throws
    func invalidate() async throws
}

final class RedisConfigCacheService: ConfigCacheServiceProtocol, @unchecked Sendable {
    private let redis: RedisClient
    private let logger: Logger
    private let ttl: TimeInterval = 300 // 5 minutes

    init(redis: RedisClient, logger: Logger) {
        self.redis = redis
        self.logger = logger
    }

    func getAll() async throws -> RemoteConfig.Response? {
        do {
            let result = try await redis.get(RedisKey("config:all"), as: Data.self).get()
            guard let data = result else {
                logger.debug("Config cache miss")
                return nil
            }

            let config = try JSONDecoder().decode(RemoteConfig.Response.self, from: data)
            logger.debug("Config cache hit")
            return config
        } catch {
            logger.error("Config cache get error - falling back to database", metadata: [
                "error": .string(error.localizedDescription)
            ])
            // Return nil to allow fallback to database instead of crashing endpoint
            return nil
        }
    }

    func set(_ config: RemoteConfig.Response) async throws {
        do {
            let data = try JSONEncoder().encode(config)
            try await redis.setex(
                RedisKey("config:all"),
                to: data,
                expirationInSeconds: Int(ttl)
            ).get()
            logger.debug("Config cached with TTL", metadata: [
                "ttl": .string("\(ttl)s")
            ])
        } catch {
            logger.error("Config cache set error", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }

    func invalidate() async throws {
        do {
            _ = try await redis.delete([RedisKey("config:all")]).get()
            logger.info("Config cache invalidated")
        } catch {
            logger.error("Config cache invalidation error", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
}

extension Application {
    private struct ConfigCacheServiceKey: StorageKey {
        typealias Value = ConfigCacheServiceProtocol
    }

    var configCacheService: ConfigCacheServiceProtocol {
        get {
            guard let service = storage[ConfigCacheServiceKey.self] else {
                fatalError("ConfigCacheService not configured. Call app.configCacheService = ... in configure.swift")
            }
            return service
        }
        set {
            storage[ConfigCacheServiceKey.self] = newValue
        }
    }
}

extension Request {
    var configCacheService: ConfigCacheServiceProtocol {
        application.configCacheService
    }
}

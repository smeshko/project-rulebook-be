import Vapor
import Foundation

struct RemoteConfigController {

    // MARK: - Public Endpoint (AC: 1, 2)

    func getConfig(_ req: Request) async throws -> RemoteConfig.Entry.Response {
        let cacheKey = "remote_config:all_active"
        let cacheTTL: TimeInterval = 300 // 5 minutes

        // Try cache first (Task 8: Redis caching)
        if let cachedJSON = await req.services.aiCache.get(key: cacheKey),
           let cachedData = cachedJSON.data(using: .utf8),
           let cached = try? JSONDecoder().decode(RemoteConfig.Entry.Response.self, from: cachedData) {
            req.logger.info("Remote config served from cache")
            return cached
        }

        // Cache miss - fetch from database
        let repository = req.repositories.remoteConfig
        let configs = try await repository.allActive()

        // Group configs by prefix (featureFlags.*, settings.*)
        var featureFlags: [String: AnyCodable] = [:]
        var settings: [String: AnyCodable] = [:]

        for config in configs {
            let parsedValue = parseConfigValue(config.value, type: config.valueType)

            if config.key.hasPrefix("featureFlags.") {
                let key = String(config.key.dropFirst("featureFlags.".count))
                featureFlags[key] = parsedValue
            } else if config.key.hasPrefix("settings.") {
                let key = String(config.key.dropFirst("settings.".count))
                settings[key] = parsedValue
            }
        }

        // Determine version (highest version number)
        let version = configs.map { $0.version }.max() ?? 1

        let response = RemoteConfig.Entry.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: "\(version).0.0"
        )

        // Cache the response
        if let responseData = try? JSONEncoder().encode(response),
           let responseJSON = String(data: responseData, encoding: .utf8) {
            await req.services.aiCache.set(key: cacheKey, value: responseJSON, ttl: cacheTTL)
            req.logger.info("Remote config cached for \(Int(cacheTTL)) seconds")
        }

        return response
    }

    // MARK: - Admin Endpoints (AC: 5)

    func createConfig(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        let repository = req.repositories.remoteConfig

        // Check for existing key
        if let _ = try await repository.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Configuration with key '\(createRequest.key)' already exists")
        }

        let config = RemoteConfigModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            version: createRequest.version ?? 1,
            isActive: createRequest.isActive ?? true
        )

        try await repository.create(config)

        // Invalidate cache
        await invalidateCache(req)

        return RemoteConfig.Create.Response(
            id: config.id!,
            key: config.key,
            message: "Configuration created successfully"
        )
    }

    func updateConfig(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key")
        }

        try RemoteConfig.Update.Request.validate(content: req)
        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        let repository = req.repositories.remoteConfig

        guard let config = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration with key '\(key)' not found")
        }

        // Update fields if provided
        if let value = updateRequest.value {
            config.value = value
        }
        if let valueType = updateRequest.valueType {
            config.valueType = valueType
        }
        if let version = updateRequest.version {
            config.version = version
        }
        if let isActive = updateRequest.isActive {
            config.isActive = isActive
        }

        try await repository.update(config)

        // Invalidate cache
        await invalidateCache(req)

        return RemoteConfig.Update.Response(
            id: config.id!,
            key: config.key,
            message: "Configuration updated successfully"
        )
    }

    func deleteConfig(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key")
        }

        let repository = req.repositories.remoteConfig

        guard let config = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration with key '\(key)' not found")
        }

        try await repository.delete(config)

        // Invalidate cache
        await invalidateCache(req)

        return RemoteConfig.Delete.Response(
            message: "Configuration deleted successfully"
        )
    }

    // MARK: - Helper Methods

    private func parseConfigValue(_ value: String, type: String) -> AnyCodable {
        switch type {
        case "boolean":
            return AnyCodable(value.lowercased() == "true")
        case "integer":
            guard let intValue = Int(value) else {
                // Log warning for invalid integer but continue with 0 for backward compatibility
                return AnyCodable(0)
            }
            return AnyCodable(intValue)
        case "json":
            if let data = value.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                // Handle both dictionaries and arrays
                if let dict = json as? [String: Any] {
                    return AnyCodable(dict.mapValues { AnyCodable($0) })
                } else if let array = json as? [Any] {
                    return AnyCodable(array.map { AnyCodable($0) })
                }
            }
            // Fall back to string for invalid JSON
            return AnyCodable(value)
        default: // string
            return AnyCodable(value)
        }
    }

    private func invalidateCache(_ req: Request) async {
        let cacheKey = "remote_config:all_active"
        await req.services.aiCache.remove(key: cacheKey)
        req.logger.info("Remote config cache invalidated")
    }
}

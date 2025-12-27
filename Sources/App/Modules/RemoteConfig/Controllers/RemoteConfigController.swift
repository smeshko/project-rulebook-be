import Vapor

struct RemoteConfigController {
    private let cacheKey = "remote_config:latest"
    private let cacheTTL = 300.0 // 5 minutes

    func getConfig(_ req: Request) async throws -> RemoteConfig.GetResponse {
        // Try cache first
        if let cached = try await req.services.cache.get(cacheKey, as: RemoteConfig.GetResponse.self) {
            return cached
        }

        // Cache miss - fetch from database
        let repository = req.repositories.remoteConfig
        let configs = try await repository.getAll()

        // Transform to response format matching AC structure
        var featureFlags: [String: RemoteConfig.AnyCodableValue] = [:]
        var settings: [String: RemoteConfig.AnyCodableValue] = [:]
        var version = "1.0.0" // Default version

        for config in configs {
            let parsedValue = parseConfigValue(config.value, type: config.valueType)

            // Route to appropriate category based on key prefix
            if config.key.hasPrefix("feature_") || config.key.hasPrefix("enable") {
                let key = config.key.replacingOccurrences(of: "feature_", with: "")
                featureFlags[key] = parsedValue
            } else if config.key == "version" {
                version = config.value
            } else {
                settings[config.key] = parsedValue
            }
        }

        let response = RemoteConfig.GetResponse(
            featureFlags: featureFlags,
            settings: settings,
            version: version
        )

        // Cache the response
        try await req.services.cache.set(cacheKey, value: response, ttl: cacheTTL)

        return response
    }

    private func parseConfigValue(_ value: String, type: ConfigValueType) -> RemoteConfig.AnyCodableValue {
        switch type {
        case .boolean:
            return .bool(value.lowercased() == "true")
        case .integer:
            return .int(Int(value) ?? 0)
        case .string:
            return .string(value)
        case .json:
            // For JSON, try to parse as object; fallback to string
            if let data = value.data(using: .utf8),
               let dict = try? JSONDecoder().decode([String: RemoteConfig.AnyCodableValue].self, from: data) {
                return .object(dict)
            }
            return .string(value)
        }
    }

    func updateConfig(_ req: Request) async throws -> RemoteConfig.UpdateResponse {
        let updateRequest = try req.content.decode(RemoteConfig.UpdateRequest.self)

        let repository = req.repositories.remoteConfig

        // Update or create config
        _ = try await repository.update(
            key: updateRequest.key,
            value: updateRequest.value,
            type: updateRequest.type
        )

        // Invalidate cache
        try await req.services.cache.delete(cacheKey)

        return RemoteConfig.UpdateResponse(
            success: true,
            key: updateRequest.key,
            message: "Configuration updated successfully"
        )
    }
}

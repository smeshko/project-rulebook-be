import Fluent
import Vapor

struct RemoteConfigController {
    // MARK: - Public Endpoint

    func getConfig(req: Request) async throws -> RemoteConfig.Response {
        // Check cache first
        if let cached = try await req.configCacheService.getAll() {
            return cached
        }

        // Cache miss - fetch from database
        let entries = try await req.remoteConfigRepository.getAllConfig()
        let response = try transformToResponse(entries: entries)

        // Cache the response (don't fail endpoint if caching fails)
        do {
            try await req.configCacheService.set(response)
        } catch {
            req.logger.error("Failed to cache config response", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }

        return response
    }

    // MARK: - Admin Endpoints

    func createOrUpdateConfig(req: Request) async throws -> RemoteConfig.ConfigEntry {
        let input = try req.content.decode(RemoteConfig.CreateConfigRequest.self)

        // Extract the actual value from AnyCodable
        let actualValue = input.value.value

        // Save to database
        let entry = try await req.remoteConfigRepository.setConfig(
            key: input.key,
            value: actualValue,
            type: input.valueType
        )

        // Invalidate cache
        try await req.configCacheService.invalidate()

        return try transformToConfigEntry(entry: entry)
    }

    func getAllConfigEntries(req: Request) async throws -> [RemoteConfig.ConfigEntry] {
        let entries = try await req.remoteConfigRepository.getAllConfig()
        return try entries.map { try transformToConfigEntry(entry: $0) }
    }

    func deleteConfig(req: Request) async throws -> HTTPStatus {
        guard let key = req.parameters.get("key"), !key.isEmpty else {
            throw Abort(.badRequest, reason: "Missing or empty key parameter")
        }

        // Check if config exists
        let exists = try await req.remoteConfigRepository.getConfig(key: key)
        guard exists != nil else {
            throw Abort(.notFound, reason: "Config key not found")
        }

        try await req.remoteConfigRepository.deleteConfig(key: key)

        // Invalidate cache
        try await req.configCacheService.invalidate()

        return .ok
    }

    // MARK: - Helper Methods

    private func transformToResponse(entries: [ConfigEntryModel]) throws -> RemoteConfig.Response {
        var featureFlags: [String: Bool] = [:]
        var settings: [String: AnyCodable] = [:]
        var version = "1.0.0"

        for entry in entries {
            let key = entry.key

            // Handle special version key
            if key == "api_version" {
                if let stringValue = entry.stringValue {
                    version = stringValue
                }
                continue
            }

            // Handle feature flags (keys prefixed with "feature_")
            if key.hasPrefix("feature_") {
                let flagKey = String(key.dropFirst("feature_".count))
                featureFlags[flagKey] = entry.boolValue ?? false
                continue
            }

            // Handle settings (keys prefixed with "setting_")
            if key.hasPrefix("setting_") {
                let settingKey = String(key.dropFirst("setting_".count))
                let value = try extractValue(from: entry)
                settings[settingKey] = value
                continue
            }
        }

        return RemoteConfig.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: version
        )
    }

    private func transformToConfigEntry(entry: ConfigEntryModel) throws -> RemoteConfig.ConfigEntry {
        let value = try extractValue(from: entry)

        return RemoteConfig.ConfigEntry(
            key: entry.key,
            valueType: entry.valueType,
            value: value,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    private func extractValue(from entry: ConfigEntryModel) throws -> AnyCodable {
        guard let type = ConfigValueType(rawValue: entry.valueType) else {
            throw Abort(.internalServerError, reason: "Invalid value type")
        }

        switch type {
        case .boolean:
            guard let value = entry.boolValue else {
                throw Abort(.internalServerError, reason: "Missing boolean value for key: \(entry.key)")
            }
            return AnyCodable(value)
        case .integer:
            guard let value = entry.intValue else {
                throw Abort(.internalServerError, reason: "Missing integer value for key: \(entry.key)")
            }
            return AnyCodable(value)
        case .string:
            guard let value = entry.stringValue else {
                throw Abort(.internalServerError, reason: "Missing string value for key: \(entry.key)")
            }
            return AnyCodable(value)
        case .json:
            guard let jsonString = entry.jsonValue,
                  let data = jsonString.data(using: .utf8) else {
                throw Abort(.internalServerError, reason: "Missing JSON value for key: \(entry.key)")
            }
            do {
                let decoded = try JSONDecoder().decode(AnyCodable.self, from: data)
                return decoded
            } catch {
                throw Abort(.internalServerError, reason: "Invalid JSON value for key: \(entry.key) - \(error.localizedDescription)")
            }
        }
    }
}

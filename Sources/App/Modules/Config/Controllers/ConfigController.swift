import Vapor

struct ConfigController {

    // MARK: - Cache Configuration
    private static let cacheKey = "config:all"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoints

    func getConfig(_ req: Request) async throws -> Config.Response {
        let cacheService = req.services.cache

        // Try cache first
        if let cached = try await cacheService.get(Self.cacheKey, as: Config.Response.self) {
            return cached
        }

        // Cache miss - build from database
        let response = try await buildConfigResponse(req)

        // Cache the response
        try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func updateConfig(_ req: Request) async throws -> Config.Update.Response {
        let updateRequest = try req.content.decode(Config.Update.Request.self)
        let repository = req.repositories.config

        var updated: [String] = []

        for entry in updateRequest.entries {
            // Find or create the config entry
            if let existing = try await repository.find(key: entry.key) {
                existing.value = entry.value
                existing.valueType = entry.valueType
                try await repository.update(existing)
            } else {
                let newEntry = ConfigEntryModel(
                    key: entry.key,
                    value: entry.value,
                    valueType: entry.valueType
                )
                try await repository.create(newEntry)
            }
            updated.append(entry.key)
        }

        // Invalidate cache
        try await req.services.cache.delete(Self.cacheKey)

        return Config.Update.Response(
            updated: updated,
            message: "Configuration updated successfully. Cache invalidated."
        )
    }

    // MARK: - Private Helpers

    private func buildConfigResponse(_ req: Request) async throws -> Config.Response {
        let repository = req.repositories.config
        let entries = try await repository.findAll()

        var featureFlags: [String: Bool] = [:]
        var settings: [String: Config.SettingValue] = [:]
        var version: String = "1.0.0"

        for entry in entries {
            if entry.key.hasPrefix("featureFlags.") {
                let flagName = String(entry.key.dropFirst("featureFlags.".count))
                if let boolValue = entry.value.boolValue {
                    featureFlags[flagName] = boolValue
                }
            } else if entry.key.hasPrefix("settings.") {
                let settingName = String(entry.key.dropFirst("settings.".count))
                settings[settingName] = parseSettingValue(entry)
            } else if entry.key == "version" {
                if let stringValue = entry.value.stringValue {
                    version = stringValue
                }
            }
        }

        return Config.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: version
        )
    }

    private func parseSettingValue(_ entry: ConfigEntryModel) -> Config.SettingValue {
        switch entry.valueType {
        case "boolean":
            return .bool(entry.value.boolValue ?? false)
        case "integer":
            return .int(entry.value.intValue ?? 0)
        case "string":
            return .string(entry.value.stringValue ?? "")
        case "object":
            return .object(entry.value.objectValue ?? [:])
        default:
            return .string(entry.value.stringValue ?? "")
        }
    }
}

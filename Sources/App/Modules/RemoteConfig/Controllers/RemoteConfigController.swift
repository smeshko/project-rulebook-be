import Foundation
import Vapor

/// Controller for managing remote configuration values.
///
/// This controller handles all remote config operations including fetching public config,
/// and admin CRUD operations for config management with comprehensive logging.
/// Implements cache-aside pattern with Redis caching for performance.
struct RemoteConfigController {

    // MARK: - Cache Configuration

    /// Cache key for storing the full config response
    private static let cacheKey = "remoteConfig:all"

    /// Cache TTL in seconds (5 minutes)
    private static let cacheTTL: TimeInterval = 300

    // MARK: - Public Config Endpoint

    /// GET /api/v1/config
    /// Returns all configuration values grouped by category.
    /// This endpoint does NOT require authentication.
    /// Uses cache-aside pattern: check cache first, fallback to DB on miss.
    func getConfig(_ req: Request) async throws -> RemoteConfig.Get.Response {
        req.logger.info("Remote config request", metadata: [
            "endpoint": "getConfig",
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // Cache-aside pattern: try cache first
        if let cachedResponse = try await getCachedConfig(req) {
            req.logger.info("Remote config served from cache", metadata: [
                "cache_hit": "true"
            ])
            return cachedResponse
        }

        // Cache miss: fetch from database
        req.logger.info("Remote config cache miss, fetching from database", metadata: [
            "cache_hit": "false"
        ])

        let response = try await fetchAndBuildResponse(req)

        // Cache the response
        try await cacheConfigResponse(req, response: response)

        req.logger.info("Remote config served from database and cached", metadata: [
            "feature_flags_count": .string("\(response.featureFlags.count)"),
            "settings_count": .string("\(response.settings.count)")
        ])

        return response
    }

    // MARK: - Admin Create Config Endpoint

    /// POST /api/v1/config
    /// Creates a new configuration entry. Requires admin authentication.
    func createConfig(_ req: Request) async throws -> RemoteConfig.Create.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        req.logger.info("Admin create config request", metadata: [
            "endpoint": "createConfig",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        let input = try req.content.decode(RemoteConfig.Create.Request.self)

        guard let valueType = ConfigValueType(rawValue: input.valueType) else {
            throw Abort(.badRequest, reason: "Invalid value_type. Must be: boolean, integer, or string")
        }

        guard let category = parseCategory(input.category) else {
            throw Abort(.badRequest, reason: "Invalid category. Must be: feature_flags or settings")
        }

        // Validate the value matches the declared type
        guard validateValue(input.value, for: valueType) else {
            throw Abort(.badRequest, reason: "Value '\(input.value)' is not a valid \(input.valueType)")
        }

        // Check if key already exists
        if let _ = try await req.repositories.remoteConfigs.find(key: input.key) {
            throw Abort(.conflict, reason: "Configuration key '\(input.key)' already exists")
        }

        let config = RemoteConfigModel(
            key: input.key,
            value: input.value,
            valueType: valueType,
            category: category
        )

        do {
            try await req.repositories.remoteConfigs.create(config)
        } catch {
            // Handle unique constraint violation for concurrent requests
            let errorString = String(reflecting: error)
            let isPostgreSQLDuplicate = errorString.contains("sqlState: 23505") &&
                (errorString.contains("uq:remote_configs.key") ||
                 errorString.contains("Key (key)") ||
                 errorString.contains("duplicate key"))
            let isSQLiteDuplicate = errorString.contains("UNIQUE constraint failed: remote_configs.key")

            if isPostgreSQLDuplicate || isSQLiteDuplicate {
                throw Abort(.conflict, reason: "Configuration key '\(input.key)' already exists")
            }
            throw error
        }

        // Invalidate cache after mutation
        try await invalidateCache(req)

        req.logger.info("Admin config created", metadata: [
            "key": .string(input.key),
            "value_type": .string(input.valueType),
            "category": .string(input.category),
            "client_ip": .string(clientIP),
            "cache_invalidated": "true"
        ])

        return RemoteConfig.Create.Response(
            id: config.id!,
            key: config.key,
            value: config.value,
            valueType: config.valueType.rawValue,
            category: config.category.rawValue,
            createdAt: config.createdAt
        )
    }

    // MARK: - Admin Update Config Endpoint

    /// PATCH /api/v1/config/:key
    /// Updates an existing configuration entry. Requires admin authentication.
    func updateConfig(_ req: Request) async throws -> RemoteConfig.Update.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing config key parameter")
        }

        req.logger.info("Admin update config request", metadata: [
            "endpoint": "updateConfig",
            "key": .string(key),
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        let input = try req.content.decode(RemoteConfig.Update.Request.self)

        guard let config = try await req.repositories.remoteConfigs.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        if let newValue = input.value {
            // Validate the new value matches the existing type
            guard validateValue(newValue, for: config.valueType) else {
                throw Abort(.badRequest, reason: "Value '\(newValue)' is not a valid \(config.valueType.rawValue)")
            }
            config.value = newValue
        }

        try await req.repositories.remoteConfigs.update(config)

        // Invalidate cache after mutation
        try await invalidateCache(req)

        req.logger.info("Admin config updated", metadata: [
            "key": .string(key),
            "new_value": .string(config.value),
            "client_ip": .string(clientIP),
            "cache_invalidated": "true"
        ])

        return RemoteConfig.Update.Response(
            id: config.id!,
            key: config.key,
            value: config.value,
            valueType: config.valueType.rawValue,
            category: config.category.rawValue,
            updatedAt: config.updatedAt
        )
    }

    // MARK: - Admin Delete Config Endpoint

    /// DELETE /api/v1/config/:key
    /// Deletes a configuration entry. Requires admin authentication.
    func deleteConfig(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing config key parameter")
        }

        req.logger.info("Admin delete config request", metadata: [
            "endpoint": "deleteConfig",
            "key": .string(key),
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        guard let _ = try await req.repositories.remoteConfigs.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        try await req.repositories.remoteConfigs.delete(key: key)

        // Invalidate cache after mutation
        try await invalidateCache(req)

        req.logger.info("Admin config deleted", metadata: [
            "key": .string(key),
            "client_ip": .string(clientIP),
            "cache_invalidated": "true"
        ])

        return RemoteConfig.Delete.Response(
            key: key,
            deleted: true,
            timestamp: Date()
        )
    }

    // MARK: - Cache Helper Methods

    /// Attempts to retrieve the config response from cache.
    private func getCachedConfig(_ req: Request) async throws -> RemoteConfig.Get.Response? {
        do {
            return try await req.services.cache.get(Self.cacheKey, as: RemoteConfig.Get.Response.self)
        } catch {
            req.logger.warning("Failed to get config from cache", metadata: [
                "error": .string(error.localizedDescription)
            ])
            return nil
        }
    }

    /// Caches the config response with TTL.
    private func cacheConfigResponse(_ req: Request, response: RemoteConfig.Get.Response) async throws {
        do {
            try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
            req.logger.debug("Config response cached", metadata: [
                "cache_key": .string(Self.cacheKey),
                "ttl_seconds": .string("\(Int(Self.cacheTTL))")
            ])
        } catch {
            req.logger.warning("Failed to cache config response", metadata: [
                "error": .string(error.localizedDescription)
            ])
            // Don't throw - caching failure shouldn't break the request
        }
    }

    /// Invalidates the config cache after mutations.
    private func invalidateCache(_ req: Request) async throws {
        do {
            try await req.services.cache.delete(Self.cacheKey)
            req.logger.debug("Config cache invalidated", metadata: [
                "cache_key": .string(Self.cacheKey)
            ])
        } catch {
            req.logger.warning("Failed to invalidate config cache", metadata: [
                "error": .string(error.localizedDescription)
            ])
            // Don't throw - cache invalidation failure shouldn't break the request
        }
    }

    /// Fetches configs from database and builds the response.
    private func fetchAndBuildResponse(_ req: Request) async throws -> RemoteConfig.Get.Response {
        let configs = try await req.repositories.remoteConfigs.findAll()

        var featureFlags: [String: AnyCodableValue] = [:]
        var settings: [String: AnyCodableValue] = [:]

        for config in configs {
            let value = parseConfigValue(config.value, type: config.valueType)

            switch config.category {
            case .featureFlags:
                featureFlags[config.key] = value
            case .settings:
                settings[config.key] = value
            }
        }

        return RemoteConfig.Get.Response(
            featureFlags: featureFlags,
            settings: settings
        )
    }

    // MARK: - Private Helper Methods

    /// Parses a string value into the appropriate typed value.
    private func parseConfigValue(_ value: String, type: ConfigValueType) -> AnyCodableValue {
        switch type {
        case .boolean:
            return .boolean(value.lowercased() == "true")
        case .integer:
            return .integer(Int(value) ?? 0)
        case .string:
            return .string(value)
        }
    }

    /// Validates that a string value can be converted to the specified type.
    private func validateValue(_ value: String, for type: ConfigValueType) -> Bool {
        switch type {
        case .boolean:
            let lowercased = value.lowercased()
            return lowercased == "true" || lowercased == "false"
        case .integer:
            return Int(value) != nil
        case .string:
            return true
        }
    }

    /// Parses category string to ConfigCategory enum.
    private func parseCategory(_ category: String) -> ConfigCategory? {
        switch category {
        case "feature_flags", "featureFlags":
            return .featureFlags
        case "settings":
            return .settings
        default:
            return nil
        }
    }
}

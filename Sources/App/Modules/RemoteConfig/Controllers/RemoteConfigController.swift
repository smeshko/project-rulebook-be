import Vapor

struct RemoteConfigController {

    /// Cache key for all remote configuration.
    private static let cacheKey = "remote_config:all"

    /// Cache TTL in seconds (5 minutes as per requirements).
    private static let cacheTTL: TimeInterval = 300

    // MARK: - Public Endpoints

    /// GET /api/v1/config
    /// Returns all configuration values grouped into featureFlags and settings.
    /// This is a public endpoint - no authentication required.
    func getConfig(_ req: Request) async throws -> RemoteConfig.Get.Response {
        // Check cache first
        if let cached: RemoteConfig.Get.Response = try await req.services.cache.get(Self.cacheKey, as: RemoteConfig.Get.Response.self) {
            req.logger.debug("Remote config cache hit")
            return cached
        }

        req.logger.debug("Remote config cache miss - fetching from database")

        // Fetch from database
        let repository = req.repositories.remoteConfig
        let configs = try await repository.all()

        // Transform flat config into nested structure
        var featureFlags: [String: AnyCodable] = [:]
        var settings: [String: AnyCodable] = [:]

        for config in configs {
            let parsedValue = parseValue(config.value, type: config.valueType)

            // Determine category based on key prefix or valueType
            // Feature flags are typically booleans, settings are other types
            if config.valueType == "boolean" {
                featureFlags[config.key] = parsedValue
            } else {
                settings[config.key] = parsedValue
            }
        }

        let response = RemoteConfig.Get.Response(
            featureFlags: featureFlags,
            settings: settings
        )

        // Cache the response
        try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
        req.logger.debug("Remote config cached with TTL \(Self.cacheTTL)s")

        return response
    }

    // MARK: - Admin Endpoints

    /// GET /api/v1/config/list
    /// Returns all configuration entries for admin management.
    func listConfigs(_ req: Request) async throws -> RemoteConfig.List.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        req.logger.info("Admin remote config list request", metadata: [
            "endpoint": "listConfigs",
            "client_ip": .string(clientIP)
        ])

        let repository = req.repositories.remoteConfig
        let configs = try await repository.all()

        let items = configs.compactMap { model -> RemoteConfig.ConfigItem? in
            guard let id = model.id, let createdAt = model.createdAt, let updatedAt = model.updatedAt else {
                return nil
            }
            return RemoteConfig.ConfigItem(
                id: id,
                key: model.key,
                value: model.value,
                valueType: model.valueType,
                createdAt: createdAt,
                updatedAt: updatedAt
            )
        }

        return RemoteConfig.List.Response(
            configs: items,
            count: items.count
        )
    }

    /// POST /api/v1/config
    /// Creates a new configuration entry. Admin only.
    func createConfig(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        req.logger.info("Admin remote config create request", metadata: [
            "key": .string(createRequest.key),
            "value_type": .string(createRequest.valueType),
            "client_ip": .string(clientIP)
        ])

        let repository = req.repositories.remoteConfig

        // Check for existing key
        if let _ = try await repository.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Configuration with key '\(createRequest.key)' already exists")
        }

        // Validate value matches declared type
        guard let valueType = RemoteConfigModel.ValueType(rawValue: createRequest.valueType),
              valueType.validate(createRequest.value) else {
            throw Abort(.badRequest, reason: "Value '\(createRequest.value)' is not valid for type '\(createRequest.valueType)'")
        }

        // Create new config entry
        let model = RemoteConfigModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType
        )
        try await repository.create(model)

        // Invalidate cache
        try await invalidateCache(req)

        req.logger.info("Admin remote config created", metadata: [
            "key": .string(createRequest.key),
            "client_ip": .string(clientIP)
        ])

        guard let id = model.id, let createdAt = model.createdAt, let updatedAt = model.updatedAt else {
            throw Abort(.internalServerError, reason: "Failed to retrieve created config metadata")
        }

        let configItem = RemoteConfig.ConfigItem(
            id: id,
            key: model.key,
            value: model.value,
            valueType: model.valueType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        return RemoteConfig.Create.Response(
            message: "Configuration created successfully",
            config: configItem
        )
    }

    /// PATCH /api/v1/config/:key
    /// Updates an existing configuration entry. Admin only.
    func updateConfig(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing key parameter")
        }

        try RemoteConfig.Update.Request.validate(content: req)
        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        req.logger.info("Admin remote config update request", metadata: [
            "key": .string(key),
            "client_ip": .string(clientIP)
        ])

        let repository = req.repositories.remoteConfig

        // Find existing config
        guard let model = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration with key '\(key)' not found")
        }

        // Determine new value type
        let newValueType = updateRequest.valueType ?? model.valueType

        // Validate value matches declared type
        guard let valueType = RemoteConfigModel.ValueType(rawValue: newValueType),
              valueType.validate(updateRequest.value) else {
            throw Abort(.badRequest, reason: "Value '\(updateRequest.value)' is not valid for type '\(newValueType)'")
        }

        // Update model
        model.value = updateRequest.value
        if let type = updateRequest.valueType {
            model.valueType = type
        }
        try await repository.update(model)

        // Invalidate cache
        try await invalidateCache(req)

        req.logger.info("Admin remote config updated", metadata: [
            "key": .string(key),
            "client_ip": .string(clientIP)
        ])

        guard let id = model.id, let createdAt = model.createdAt, let updatedAt = model.updatedAt else {
            throw Abort(.internalServerError, reason: "Failed to retrieve updated config metadata")
        }

        let configItem = RemoteConfig.ConfigItem(
            id: id,
            key: model.key,
            value: model.value,
            valueType: model.valueType,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        return RemoteConfig.Update.Response(
            message: "Configuration updated successfully",
            config: configItem
        )
    }

    /// DELETE /api/v1/config/:key
    /// Deletes a configuration entry. Admin only.
    func deleteConfig(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing key parameter")
        }

        let clientIP = req.services.ipExtractor.extractClientIP(from: req)

        req.logger.info("Admin remote config delete request", metadata: [
            "key": .string(key),
            "client_ip": .string(clientIP)
        ])

        let repository = req.repositories.remoteConfig

        // Find existing config
        guard let model = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration with key '\(key)' not found")
        }

        try await repository.delete(model)

        // Invalidate cache
        try await invalidateCache(req)

        req.logger.info("Admin remote config deleted", metadata: [
            "key": .string(key),
            "client_ip": .string(clientIP)
        ])

        return RemoteConfig.Delete.Response(
            message: "Configuration deleted successfully",
            deleted: true
        )
    }

    // MARK: - Private Helpers

    /// Invalidates the remote config cache.
    private func invalidateCache(_ req: Request) async throws {
        try await req.services.cache.delete(Self.cacheKey)
        req.logger.debug("Remote config cache invalidated")
    }

    /// Parses a string value to the appropriate type based on valueType.
    private func parseValue(_ value: String, type: String) -> AnyCodable {
        switch type {
        case "boolean":
            return AnyCodable(value.lowercased() == "true")
        case "integer":
            if let intValue = Int(value) {
                return AnyCodable(intValue)
            }
            return AnyCodable(value)
        case "string":
            return AnyCodable(value)
        default:
            return AnyCodable(value)
        }
    }
}

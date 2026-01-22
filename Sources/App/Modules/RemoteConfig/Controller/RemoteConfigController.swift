import Vapor

struct RemoteConfigController {

    /// Cache key for the entire remote config response.
    private static let cacheKey = "remote_config_all"

    /// Cache TTL in seconds (5 minutes).
    private static let cacheTTL: TimeInterval = 300

    // MARK: - Public Endpoint

    func getConfig(_ req: Request) async throws -> RemoteConfig.Get.Response {
        // Check cache first
        if let cached = try await req.services.cache.get(Self.cacheKey, as: RemoteConfig.Get.Response.self) {
            req.logger.debug("Cache hit for remote config")
            return cached
        }

        req.logger.debug("Cache miss for remote config, fetching from database")

        // Fetch from database
        let repository = req.repositories.remoteConfig
        let entries = try await repository.findAll()

        // Transform to response format
        let response = transformToResponse(entries)

        // Cache the response
        try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func listAllConfig(_ req: Request) async throws -> RemoteConfig.List.Response {
        let repository = req.repositories.remoteConfig
        let entries = try await repository.findAll()

        let responseEntries = entries.map { entry in
            RemoteConfig.List.Entry(
                id: entry.id!,
                key: entry.key,
                value: entry.value,
                valueType: entry.valueType.rawValue,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }

        return RemoteConfig.List.Response(entries: responseEntries)
    }

    func createConfig(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        let repository = req.repositories.remoteConfig

        // Check if key already exists
        if try await repository.find(key: createRequest.key) != nil {
            throw Abort(.conflict, reason: "Configuration key '\(createRequest.key)' already exists")
        }

        guard let valueType = ConfigValueType(rawValue: createRequest.valueType) else {
            throw Abort(.badRequest, reason: "Invalid value type: \(createRequest.valueType)")
        }

        // Validate value matches type
        try validateValueMatchesType(createRequest.value, type: valueType)

        let model = RemoteConfigModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: valueType
        )

        try await repository.create(model)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Create.Response(
            id: model.id!,
            key: model.key,
            value: model.value,
            valueType: model.valueType.rawValue,
            message: "Configuration entry created successfully"
        )
    }

    func updateConfig(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key")
        }

        try RemoteConfig.Update.Request.validate(content: req)
        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        let repository = req.repositories.remoteConfig

        guard let model = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        // Determine value type (use existing if not provided)
        let valueType: ConfigValueType
        if let newTypeString = updateRequest.valueType,
           let newType = ConfigValueType(rawValue: newTypeString) {
            valueType = newType
        } else {
            valueType = model.valueType
        }

        // Validate value matches type
        try validateValueMatchesType(updateRequest.value, type: valueType)

        model.value = updateRequest.value
        model.valueType = valueType

        try await repository.update(model)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Update.Response(
            id: model.id!,
            key: model.key,
            value: model.value,
            valueType: model.valueType.rawValue,
            message: "Configuration entry updated successfully"
        )
    }

    func deleteConfig(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key")
        }

        let repository = req.repositories.remoteConfig

        guard let model = try await repository.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        try await repository.delete(model)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Delete.Response(
            key: key,
            message: "Configuration entry deleted successfully"
        )
    }

    // MARK: - Private Helpers

    /// Transforms database entries into the public response format.
    private func transformToResponse(_ entries: [RemoteConfigModel]) -> RemoteConfig.Get.Response {
        var featureFlags: [String: Bool] = [:]
        var settings: [String: AnyCodableValue] = [:]

        for entry in entries {
            // Parse key to determine category
            let parts = entry.key.split(separator: ".", maxSplits: 1)

            if parts.count == 2 {
                let category = String(parts[0])
                let name = String(parts[1])

                switch category {
                case "featureFlags":
                    if entry.valueType == .boolean {
                        featureFlags[name] = entry.value.lowercased() == "true"
                    }
                case "settings":
                    switch entry.valueType {
                    case .boolean:
                        settings[name] = .bool(entry.value.lowercased() == "true")
                    case .integer:
                        settings[name] = .int(Int(entry.value) ?? 0)
                    case .string:
                        settings[name] = .string(entry.value)
                    }
                default:
                    // Unknown category - add to settings
                    switch entry.valueType {
                    case .boolean:
                        settings[entry.key] = .bool(entry.value.lowercased() == "true")
                    case .integer:
                        settings[entry.key] = .int(Int(entry.value) ?? 0)
                    case .string:
                        settings[entry.key] = .string(entry.value)
                    }
                }
            } else {
                // No category prefix - add to settings
                switch entry.valueType {
                case .boolean:
                    settings[entry.key] = .bool(entry.value.lowercased() == "true")
                case .integer:
                    settings[entry.key] = .int(Int(entry.value) ?? 0)
                case .string:
                    settings[entry.key] = .string(entry.value)
                }
            }
        }

        return RemoteConfig.Get.Response(
            featureFlags: featureFlags,
            settings: settings
        )
    }

    /// Validates that the value can be parsed as the specified type.
    private func validateValueMatchesType(_ value: String, type: ConfigValueType) throws {
        switch type {
        case .boolean:
            let lowercased = value.lowercased()
            if lowercased != "true" && lowercased != "false" {
                throw Abort(.badRequest, reason: "Value '\(value)' is not a valid boolean (use 'true' or 'false')")
            }
        case .integer:
            if Int(value) == nil {
                throw Abort(.badRequest, reason: "Value '\(value)' is not a valid integer")
            }
        case .string:
            // Any string is valid
            break
        }
    }

    /// Invalidates the remote config cache.
    private func invalidateCache(_ req: Request) async throws {
        try await req.services.cache.delete(Self.cacheKey)
        req.logger.debug("Remote config cache invalidated")
    }
}

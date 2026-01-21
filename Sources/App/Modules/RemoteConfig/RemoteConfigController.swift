import Vapor

struct RemoteConfigController {

    // Cache key for remote config
    private static let cacheKey = "remote-config:current"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoints

    func getConfig(_ req: Request) async throws -> RemoteConfig.Response {
        // Try cache first (skip in testing environment)
        if req.application.environment != .testing {
            if let cached: RemoteConfig.Response = try await req.services.cache.get(Self.cacheKey, as: RemoteConfig.Response.self) {
                req.logger.debug("Remote config cache hit")
                return cached
            }
            req.logger.debug("Remote config cache miss")
        }

        // Fetch from database
        let repository = req.repositories.remoteConfig
        let entries = try await repository.all()

        // Build response
        let response = buildConfigResponse(from: entries)

        // Cache the result (skip in testing environment)
        if req.application.environment != .testing {
            try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)
        }

        return response
    }

    // MARK: - Admin Endpoints

    func list(_ req: Request) async throws -> RemoteConfig.List.Response {
        let repository = req.repositories.remoteConfig
        let entries = try await repository.all()
        let total = try await repository.count()

        return RemoteConfig.List.Response(
            items: entries.map { $0.toListItem() },
            total: total
        )
    }

    func create(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        let repository = req.repositories.remoteConfig

        // Check for duplicate key
        if let existing = try await repository.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Configuration key '\(existing.key)' already exists")
        }

        // Validate value matches type
        try validateValueType(value: createRequest.value, type: createRequest.valueType)

        let entry = RemoteConfigEntryModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            description: createRequest.description
        )

        do {
            try await repository.create(entry)
        } catch {
            // Handle race condition: unique constraint violation if concurrent creates
            let errorString = String(reflecting: error)
            let isPostgreSQLDuplicate = errorString.contains("sqlState: 23505") ||
                (errorString.contains("duplicate key") && errorString.contains("key"))
            let isSQLiteDuplicate = errorString.contains("UNIQUE constraint failed: remote_config_entries.key")

            if isPostgreSQLDuplicate || isSQLiteDuplicate {
                throw Abort(.conflict, reason: "Configuration key '\(createRequest.key)' already exists")
            }
            throw error
        }

        // Invalidate cache
        try await invalidateCache(req)

        return entry.toCreateResponse()
    }

    func update(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid or missing config entry ID")
        }

        let repository = req.repositories.remoteConfig
        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration entry not found")
        }

        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        // Update fields if provided
        if let value = updateRequest.value {
            let valueType = updateRequest.valueType ?? entry.valueType
            try validateValueType(value: value, type: valueType)
            entry.value = value
        }

        if let valueType = updateRequest.valueType {
            try validateValueType(value: entry.value, type: valueType)
            entry.valueType = valueType
        }

        if let description = updateRequest.description {
            entry.description = description
        }

        try await repository.update(entry)

        // Invalidate cache
        try await invalidateCache(req)

        return entry.toUpdateResponse()
    }

    func delete(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid or missing config entry ID")
        }

        let repository = req.repositories.remoteConfig
        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration entry not found")
        }

        try await repository.delete(entry)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Delete.Response(message: "Configuration entry deleted successfully")
    }

    // MARK: - Private Helpers

    private func buildConfigResponse(from entries: [RemoteConfigEntryModel]) -> RemoteConfig.Response {
        var featureFlags: [String: Bool] = [:]
        var settings: [String: AnyCodable] = [:]

        for entry in entries {
            switch entry.valueType {
            case .boolean:
                let boolValue = entry.value.lowercased() == "true"
                featureFlags[entry.key] = boolValue
            case .integer:
                if let intValue = Int(entry.value) {
                    settings[entry.key] = AnyCodable(intValue)
                }
            case .string:
                settings[entry.key] = AnyCodable(entry.value)
            case .json:
                if let data = entry.value.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                    settings[entry.key] = AnyCodable(json)
                }
            }
        }

        // Get version from entries or default
        let version = (settings["version"]?.value as? String) ?? "1.0.0"

        return RemoteConfig.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: version
        )
    }

    private func validateValueType(value: String, type: RemoteConfig.ValueType) throws {
        switch type {
        case .boolean:
            let lowered = value.lowercased()
            guard lowered == "true" || lowered == "false" else {
                throw Abort(.badRequest, reason: "Invalid boolean value. Use 'true' or 'false'")
            }
        case .integer:
            guard Int(value) != nil else {
                throw Abort(.badRequest, reason: "Invalid integer value")
            }
        case .string:
            // Any string is valid
            break
        case .json:
            guard let data = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data, options: [])) != nil else {
                throw Abort(.badRequest, reason: "Invalid JSON value")
            }
        }
    }

    private func invalidateCache(_ req: Request) async throws {
        if req.application.environment != .testing {
            try await req.services.cache.delete(Self.cacheKey)
            req.logger.info("Remote config cache invalidated")
        }
    }
}

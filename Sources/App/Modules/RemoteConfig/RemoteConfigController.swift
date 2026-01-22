import Vapor

struct RemoteConfigController {

    // MARK: - Cache Constants

    private static let publicConfigCacheKey = "remote_config:public"
    private static let publicConfigCacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoint

    /// GET /api/v1/config
    /// Returns public configuration with feature flags and settings for mobile clients.
    func getPublicConfig(_ req: Request) async throws -> RemoteConfig.Public.Response {
        // Try cache first
        do {
            if let cached: RemoteConfig.Public.Response = try await req.services.cache.get(
                Self.publicConfigCacheKey,
                as: RemoteConfig.Public.Response.self
            ) {
                req.logger.debug("Remote config cache hit")
                return cached
            }
        } catch {
            // Cache failure - log and continue to database fallback
            req.logger.warning("Remote config cache get failed, falling back to database", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }

        // Cache miss or failure - fetch from database
        let entries = try await req.repositories.remoteConfig.findAll()
        let response = buildPublicResponse(from: entries)

        // Try to cache the response
        do {
            try await req.services.cache.set(
                Self.publicConfigCacheKey,
                value: response,
                ttl: Self.publicConfigCacheTTL
            )
            req.logger.debug("Remote config cached successfully")
        } catch {
            // Cache set failure - log but don't fail the request
            req.logger.warning("Remote config cache set failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }

        return response
    }

    // MARK: - Admin Endpoints

    /// GET /api/v1/admin/config
    /// Lists all config entries.
    func listEntries(_ req: Request) async throws -> RemoteConfig.List.Response {
        let entries = try await req.repositories.remoteConfig.findAll()

        let responseEntries = entries.map { entry in
            RemoteConfig.List.Entry(
                id: entry.id!,
                key: entry.key,
                value: entry.value,
                valueType: entry.valueType,
                description: entry.description,
                createdAt: entry.createdAt,
                updatedAt: entry.updatedAt
            )
        }

        return RemoteConfig.List.Response(
            entries: responseEntries,
            count: responseEntries.count
        )
    }

    /// POST /api/v1/admin/config
    /// Creates a new config entry.
    func createEntry(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        // Validate value type
        guard let valueType = RemoteConfig.ValueType(rawValue: createRequest.valueType) else {
            throw Abort(.badRequest, reason: "Invalid value type: \(createRequest.valueType)")
        }

        // Validate value against declared type
        try validateValue(createRequest.value, for: valueType)

        // Check for existing entry with same key
        if let _ = try await req.repositories.remoteConfig.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Config entry with key '\(createRequest.key)' already exists")
        }

        let entry = RemoteConfigEntryModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            description: createRequest.description
        )

        try await req.repositories.remoteConfig.create(entry)

        // Invalidate public config cache
        await invalidatePublicCache(req)

        req.logger.info("Remote config entry created", metadata: [
            "key": .string(entry.key),
            "valueType": .string(entry.valueType)
        ])

        return RemoteConfig.Create.Response(
            id: entry.id!,
            key: entry.key,
            value: entry.value,
            valueType: entry.valueType,
            description: entry.description,
            createdAt: entry.createdAt,
            message: "Config entry created successfully"
        )
    }

    /// PATCH /api/v1/admin/config/:key
    /// Updates an existing config entry.
    func updateEntry(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing key parameter")
        }

        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        guard let entry = try await req.repositories.remoteConfig.find(key: key) else {
            throw Abort(.notFound, reason: "Config entry with key '\(key)' not found")
        }

        // Update value if provided
        if let newValue = updateRequest.value {
            let effectiveType = updateRequest.valueType ?? entry.valueType
            guard let valueType = RemoteConfig.ValueType(rawValue: effectiveType) else {
                throw Abort(.badRequest, reason: "Invalid value type: \(effectiveType)")
            }
            try validateValue(newValue, for: valueType)
            entry.value = newValue
        }

        // Update value type if provided
        if let newValueType = updateRequest.valueType {
            guard RemoteConfig.ValueType(rawValue: newValueType) != nil else {
                throw Abort(.badRequest, reason: "Invalid value type: \(newValueType)")
            }
            // Re-validate existing value against new type if value wasn't also updated
            if updateRequest.value == nil {
                guard let valueType = RemoteConfig.ValueType(rawValue: newValueType) else {
                    throw Abort(.badRequest, reason: "Invalid value type: \(newValueType)")
                }
                try validateValue(entry.value, for: valueType)
            }
            entry.valueType = newValueType
        }

        // Update description if provided (allow setting to nil)
        if let newDescription = updateRequest.description {
            entry.description = newDescription
        }

        try await req.repositories.remoteConfig.update(entry)

        // Invalidate public config cache
        await invalidatePublicCache(req)

        req.logger.info("Remote config entry updated", metadata: [
            "key": .string(entry.key)
        ])

        return RemoteConfig.Update.Response(
            id: entry.id!,
            key: entry.key,
            value: entry.value,
            valueType: entry.valueType,
            description: entry.description,
            updatedAt: entry.updatedAt,
            message: "Config entry updated successfully"
        )
    }

    /// DELETE /api/v1/admin/config/:key
    /// Deletes a config entry.
    func deleteEntry(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing key parameter")
        }

        guard let entry = try await req.repositories.remoteConfig.find(key: key) else {
            throw Abort(.notFound, reason: "Config entry with key '\(key)' not found")
        }

        try await req.repositories.remoteConfig.delete(entry)

        // Invalidate public config cache
        await invalidatePublicCache(req)

        req.logger.info("Remote config entry deleted", metadata: [
            "key": .string(key)
        ])

        return RemoteConfig.Delete.Response(
            key: key,
            message: "Config entry deleted successfully"
        )
    }

    // MARK: - Private Helpers

    /// Builds the public response from database entries, separating booleans into featureFlags.
    private func buildPublicResponse(from entries: [RemoteConfigEntryModel]) -> RemoteConfig.Public.Response {
        var featureFlags: [String: Bool] = [:]
        var settings: [String: AnyCodable] = [:]

        for entry in entries {
            if entry.valueType == RemoteConfig.ValueType.boolean.rawValue {
                // Parse boolean value
                let boolValue = entry.value.lowercased() == "true" || entry.value == "1"
                featureFlags[entry.key] = boolValue
            } else {
                // Parse other values based on type
                let parsedValue = parseValue(entry.value, type: entry.valueType)
                settings[entry.key] = parsedValue
            }
        }

        return RemoteConfig.Public.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: Date()
        )
    }

    /// Parses a string value into an AnyCodable based on the declared type.
    private func parseValue(_ value: String, type: String) -> AnyCodable {
        switch type {
        case RemoteConfig.ValueType.integer.rawValue:
            if let intValue = Int(value) {
                return AnyCodable(intValue)
            }
            return AnyCodable(value)

        case RemoteConfig.ValueType.string.rawValue:
            return AnyCodable(value)

        case RemoteConfig.ValueType.json.rawValue:
            if let data = value.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data, options: []) {
                return AnyCodable(json)
            }
            return AnyCodable(value)

        default:
            return AnyCodable(value)
        }
    }

    /// Validates that a value matches the declared type.
    private func validateValue(_ value: String, for type: RemoteConfig.ValueType) throws {
        switch type {
        case .boolean:
            let lower = value.lowercased()
            guard lower == "true" || lower == "false" || value == "1" || value == "0" else {
                throw Abort(.badRequest, reason: "Invalid boolean value: '\(value)'. Expected 'true', 'false', '1', or '0'")
            }

        case .integer:
            guard Int(value) != nil else {
                throw Abort(.badRequest, reason: "Invalid integer value: '\(value)'")
            }

        case .string:
            // All strings are valid
            break

        case .json:
            guard let data = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data, options: [])) != nil else {
                throw Abort(.badRequest, reason: "Invalid JSON value: '\(value)'")
            }
        }
    }

    /// Invalidates the public config cache.
    private func invalidatePublicCache(_ req: Request) async {
        do {
            try await req.services.cache.delete(Self.publicConfigCacheKey)
            req.logger.debug("Remote config cache invalidated")
        } catch {
            req.logger.warning("Failed to invalidate remote config cache", metadata: [
                "error": .string(error.localizedDescription)
            ])
        }
    }
}

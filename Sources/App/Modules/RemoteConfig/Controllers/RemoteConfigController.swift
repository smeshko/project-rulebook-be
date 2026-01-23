import Vapor

/// Controller for remote configuration endpoints.
///
/// Provides public read access to configuration and admin-only write operations.
/// Uses Redis caching with 5-minute TTL for the public GET endpoint.
struct RemoteConfigController {

    // MARK: - GET /api/v1/config (Public)

    /// Retrieves all configuration values grouped by category.
    ///
    /// This endpoint is public (no authentication required) and uses Redis caching
    /// with a 5-minute TTL. On cache miss, fetches from PostgreSQL and caches.
    ///
    /// - Parameter req: The incoming request.
    /// - Returns: Configuration response with featureFlags and settings.
    func getConfig(_ req: Request) async throws -> RemoteConfig.Get.Response {
        // Check cache first
        if let cached = await req.remoteConfigCache.getCachedConfig() {
            return cached
        }

        // Cache miss - fetch from database
        let configs = try await req.services.remoteConfig.all()

        // Transform to response structure
        let response = transformToResponse(configs)

        // Cache the result
        await req.remoteConfigCache.setCachedConfig(response)

        return response
    }

    // MARK: - POST /api/v1/config (Admin Only)

    /// Creates a new configuration entry.
    ///
    /// Requires admin authentication. Validates that the key is unique.
    /// Invalidates the cache after successful creation.
    ///
    /// - Parameter req: The incoming request with Create.Request body.
    /// - Returns: The created configuration item.
    /// - Throws: 400 if key already exists, validation errors.
    func createConfig(_ req: Request) async throws -> RemoteConfig.Item.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let input = try req.content.decode(RemoteConfig.Create.Request.self)

        // Validate value matches declared type
        try input.validateValueMatchesType()

        // Check for duplicate key
        if let _ = try await req.services.remoteConfig.find(key: input.key) {
            throw Abort(.badRequest, reason: "Configuration key '\(input.key)' already exists")
        }

        // Create the model
        let model = RemoteConfigModel(
            key: input.key,
            value: input.value,
            valueType: input.valueType,
            category: input.category
        )

        do {
            try await req.services.remoteConfig.create(model)
        } catch {
            // Handle unique constraint violation (race condition or soft-deleted key conflict)
            if "\(error)".contains("UNIQUE constraint") || "\(error)".contains("duplicate key") {
                throw Abort(.conflict, reason: "Configuration key '\(input.key)' already exists")
            }
            throw error
        }

        // Invalidate cache
        await req.remoteConfigCache.invalidateCache()

        req.logger.info("Remote config created", metadata: [
            "key": .string(input.key),
            "category": .string(input.category.rawValue)
        ])

        return try RemoteConfig.Item.Response(from: model)
    }

    // MARK: - PATCH /api/v1/config/:key (Admin Only)

    /// Updates an existing configuration entry.
    ///
    /// Requires admin authentication. Only updates provided fields.
    /// Invalidates the cache after successful update.
    ///
    /// - Parameter req: The incoming request with Update.Request body and key path param.
    /// - Returns: The updated configuration item.
    /// - Throws: 404 if key not found.
    func updateConfig(_ req: Request) async throws -> RemoteConfig.Item.Response {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key parameter")
        }

        guard let model = try await req.services.remoteConfig.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        let input = try req.content.decode(RemoteConfig.Update.Request.self)

        // Validate value/type compatibility
        // If updating valueType, check against existing or new value
        let effectiveValue = input.value ?? model.value
        try input.validateValueMatchesType(existingValue: effectiveValue)

        // Apply updates
        if let value = input.value {
            model.value = value
        }
        if let valueType = input.valueType {
            model.valueType = valueType
        }
        if let category = input.category {
            model.category = category
        }

        try await req.services.remoteConfig.update(model)

        // Invalidate cache
        await req.remoteConfigCache.invalidateCache()

        req.logger.info("Remote config updated", metadata: [
            "key": .string(key)
        ])

        return try RemoteConfig.Item.Response(from: model)
    }

    // MARK: - DELETE /api/v1/config/:key (Admin Only)

    /// Soft-deletes a configuration entry.
    ///
    /// Requires admin authentication. Uses soft delete (sets deletedAt).
    /// Invalidates the cache after successful deletion.
    ///
    /// - Parameter req: The incoming request with key path param.
    /// - Returns: 204 No Content on success.
    /// - Throws: 404 if key not found.
    func deleteConfig(_ req: Request) async throws -> HTTPStatus {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing configuration key parameter")
        }

        guard let model = try await req.services.remoteConfig.find(key: key) else {
            throw Abort(.notFound, reason: "Configuration key '\(key)' not found")
        }

        try await req.services.remoteConfig.delete(model)

        // Invalidate cache
        await req.remoteConfigCache.invalidateCache()

        req.logger.info("Remote config deleted", metadata: [
            "key": .string(key)
        ])

        return .noContent
    }

    // MARK: - Private Helpers

    /// Transforms database models into the grouped response structure.
    private func transformToResponse(_ configs: [RemoteConfigModel]) -> RemoteConfig.Get.Response {
        var featureFlags: [String: AnyCodableValue] = [:]
        var settings: [String: AnyCodableValue] = [:]

        for config in configs {
            let typedValue = AnyCodableValue.from(stringValue: config.value, type: config.valueType)

            switch config.category {
            case .featureFlag:
                featureFlags[config.key] = typedValue
            case .setting:
                settings[config.key] = typedValue
            }
        }

        return RemoteConfig.Get.Response(
            featureFlags: featureFlags,
            settings: settings
        )
    }
}

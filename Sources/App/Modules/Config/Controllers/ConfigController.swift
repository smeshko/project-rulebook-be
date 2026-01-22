import Vapor

struct ConfigController {
    private static let cacheKey = "config:all"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoint (No Auth Required)

    func getConfig(_ req: Request) async throws -> Config.Get.Response {
        // Try to get from cache first
        if let cached = try await req.services.cache.get(Self.cacheKey, as: Config.Get.Response.self) {
            return cached
        }

        // Cache miss - fetch from database
        let repository = req.repositories.config
        let entries = try await repository.all()

        let response = buildConfigResponse(from: entries)

        // Cache the result
        try await req.services.cache.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func listConfigs(_ req: Request) async throws -> Config.List.Response {
        let repository = req.repositories.config
        let entries = try await repository.all()

        return Config.List.Response(
            entries: try entries.map { try Config.Entry.Response(from: $0) }
        )
    }

    func createConfig(_ req: Request) async throws -> Config.Entry.Response {
        try Config.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(Config.Create.Request.self)

        let repository = req.repositories.config

        // Check if key already exists
        if let _ = try await repository.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Config key '\(createRequest.key)' already exists")
        }

        let entry = ConfigEntryModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            category: createRequest.category
        )

        try await repository.create(entry)

        // Invalidate cache after creation
        try await invalidateCache(req)

        return try Config.Entry.Response(from: entry)
    }

    func updateConfig(_ req: Request) async throws -> Config.Entry.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid config ID")
        }

        try Config.Update.Request.validate(content: req)
        let updateRequest = try req.content.decode(Config.Update.Request.self)

        let repository = req.repositories.config

        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Config entry not found")
        }

        // Update fields if provided
        if let value = updateRequest.value {
            entry.value = value
        }
        if let valueType = updateRequest.valueType {
            entry.valueType = valueType
        }
        if let category = updateRequest.category {
            entry.category = category
        }

        try await repository.update(entry)

        // Invalidate cache after update
        try await invalidateCache(req)

        return try Config.Entry.Response(from: entry)
    }

    func deleteConfig(_ req: Request) async throws -> HTTPStatus {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid config ID")
        }

        let repository = req.repositories.config

        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Config entry not found")
        }

        try await repository.delete(entry)

        // Invalidate cache after deletion
        try await invalidateCache(req)

        return .noContent
    }

    // MARK: - Private Helpers

    private func buildConfigResponse(from entries: [ConfigEntryModel]) -> Config.Get.Response {
        var featureFlags: [String: ConfigValue] = [:]
        var settings: [String: ConfigValue] = [:]

        for entry in entries {
            let value = ConfigValue.from(rawValue: entry.value, type: entry.valueType)

            switch entry.category {
            case .featureFlag:
                featureFlags[entry.key] = value
            case .setting:
                settings[entry.key] = value
            }
        }

        return Config.Get.Response(featureFlags: featureFlags, settings: settings)
    }

    private func invalidateCache(_ req: Request) async throws {
        try await req.services.cache.delete(Self.cacheKey)
    }
}

import Vapor

struct ConfigController {

    private static let cacheKey = "config:all"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes
    private static let allowedTypes = ["boolean", "integer", "string", "json"]

    // MARK: - Public Endpoints

    func getConfig(req: Request) async throws -> Config.Response {
        let cacheService = req.services.cache

        // Try cache first
        if let cached = try await cacheService.get(Self.cacheKey, as: Config.Response.self) {
            return cached
        }

        // Cache miss - fetch from database
        let repository = req.repositories.config
        let entries = try await repository.findAll()

        let response = Config.Response.from(entries: entries)

        // Cache the response
        try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func listConfig(req: Request) async throws -> Config.Admin.ListResponse {
        let repository = req.repositories.config
        let entries = try await repository.findAll()

        return Config.Admin.ListResponse(
            entries: entries.map { Config.Admin.ConfigEntryResponse.from($0) }
        )
    }

    func createConfig(req: Request) async throws -> Config.Admin.ConfigEntryResponse {
        let createRequest = try req.content.decode(Config.Admin.CreateRequest.self)
        let repository = req.repositories.config

        // Validate type
        guard Self.allowedTypes.contains(createRequest.type) else {
            throw ConfigError.invalidValue("Invalid type '\(createRequest.type)'. Must be one of: \(Self.allowedTypes.joined(separator: ", "))")
        }

        // Check if key already exists
        if try await repository.find(key: createRequest.key) != nil {
            throw ConfigError.keyAlreadyExists(createRequest.key)
        }

        let entry = ConfigEntryModel(
            key: createRequest.key,
            value: createRequest.value,
            type: createRequest.type
        )

        try await repository.create(entry)

        // Invalidate cache
        try await invalidateCache(req: req)

        return Config.Admin.ConfigEntryResponse.from(entry)
    }

    func updateConfig(req: Request) async throws -> Config.Admin.ConfigEntryResponse {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing config key")
        }

        let updateRequest = try req.content.decode(Config.Admin.UpdateRequest.self)
        let repository = req.repositories.config

        guard let entry = try await repository.find(key: key) else {
            throw ConfigError.notFound(key)
        }

        entry.value = updateRequest.value
        if let type = updateRequest.type {
            // Validate type if provided
            guard Self.allowedTypes.contains(type) else {
                throw ConfigError.invalidValue("Invalid type '\(type)'. Must be one of: \(Self.allowedTypes.joined(separator: ", "))")
            }
            entry.type = type
        }

        try await repository.update(entry)

        // Invalidate cache
        try await invalidateCache(req: req)

        return Config.Admin.ConfigEntryResponse.from(entry)
    }

    func deleteConfig(req: Request) async throws -> Config.Admin.DeleteResponse {
        guard let key = req.parameters.get("key") else {
            throw Abort(.badRequest, reason: "Missing config key")
        }

        let repository = req.repositories.config

        guard let entry = try await repository.find(key: key) else {
            throw ConfigError.notFound(key)
        }

        try await repository.delete(entry)

        // Invalidate cache
        try await invalidateCache(req: req)

        return Config.Admin.DeleteResponse(
            message: "Config entry '\(key)' deleted successfully"
        )
    }

    // MARK: - Private Helpers

    private func invalidateCache(req: Request) async throws {
        try await req.services.cache.delete(Self.cacheKey)
    }
}

import Vapor

struct ConfigController {

    private static let cacheKey = "config:all"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoints

    func getConfig(_ req: Request) async throws -> Config.Response {
        // Try cache first
        if let cached = try await req.application.cacheService.get(Self.cacheKey, as: Config.Response.self) {
            return cached
        }

        // Cache miss - fetch from database
        let repository = req.repositories.config
        let values = try await repository.all()

        // Build response from database values
        let response = Config.Response(from: values)

        // Cache the response
        try await req.application.cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func updateConfig(_ req: Request) async throws -> Config.Response {
        let updateRequest = try req.content.decode(Config.Update.Request.self)
        let repository = req.repositories.config

        // Update each provided config value
        for item in updateRequest.items {
            if let existing = try await repository.find(key: item.key) {
                existing.value = item.value
                existing.valueType = item.valueType.rawValue
                try await repository.update(existing)
            } else {
                let newConfig = ConfigValueModel(
                    key: item.key,
                    value: item.value,
                    valueType: item.valueType.rawValue
                )
                try await repository.create(newConfig)
            }
        }

        // Invalidate cache
        try await req.application.cacheService.delete(Self.cacheKey)

        // Return updated config
        let values = try await repository.all()
        return Config.Response(from: values)
    }
}

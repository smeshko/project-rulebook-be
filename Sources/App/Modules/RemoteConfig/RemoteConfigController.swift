import Vapor

struct RemoteConfigController {
    private static let cacheKey = "remote_config_public"
    private static let cacheTTL: TimeInterval = 300 // 5 minutes

    // MARK: - Public Endpoint

    func getConfig(_ req: Request) async throws -> RemoteConfig.Response {
        let cacheService = req.application.cacheService

        // Try cache first
        if let cached = try await cacheService.get(Self.cacheKey, as: RemoteConfig.Response.self) {
            return cached
        }

        // Cache miss - build response from database
        let repository = req.repositories.remoteConfig
        let entries = try await repository.all()

        let response = buildConfigResponse(from: entries)

        // Cache the response
        try await cacheService.set(Self.cacheKey, value: response, ttl: Self.cacheTTL)

        return response
    }

    // MARK: - Admin Endpoints

    func list(_ req: Request) async throws -> RemoteConfig.List.Response {
        let repository = req.repositories.remoteConfig
        let entries = try await repository.all()
        let total = try await repository.count()

        return RemoteConfig.List.Response(
            entries: entries.map { entry in
                RemoteConfig.List.Entry(
                    id: entry.id!,
                    key: entry.key,
                    value: entry.value,
                    valueType: entry.parsedValueType,
                    description: entry.description,
                    createdAt: entry.createdAt,
                    updatedAt: entry.updatedAt
                )
            },
            total: total
        )
    }

    func get(_ req: Request) async throws -> RemoteConfig.Detail.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }

        let repository = req.repositories.remoteConfig
        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration entry not found")
        }

        return RemoteConfig.Detail.Response(
            id: entry.id!,
            key: entry.key,
            value: entry.value,
            valueType: entry.parsedValueType,
            description: entry.description,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }

    func create(_ req: Request) async throws -> RemoteConfig.Create.Response {
        try RemoteConfig.Create.Request.validate(content: req)
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        // Validate value matches declared type
        try validateValueType(value: createRequest.value, type: createRequest.valueType)

        let repository = req.repositories.remoteConfig

        // Check for duplicate key
        if let _ = try await repository.find(key: createRequest.key) {
            throw Abort(.conflict, reason: "Configuration key already exists")
        }

        let entry = RemoteConfigEntryModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            description: createRequest.description
        )

        try await repository.create(entry)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Create.Response(
            id: entry.id!,
            key: entry.key,
            value: entry.value,
            valueType: entry.parsedValueType,
            description: entry.description,
            createdAt: entry.createdAt
        )
    }

    func update(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }

        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)

        let repository = req.repositories.remoteConfig
        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration entry not found")
        }

        // Apply partial updates
        if let newValue = updateRequest.value {
            let typeToValidate = updateRequest.valueType ?? entry.parsedValueType
            try validateValueType(value: newValue, type: typeToValidate)
            entry.value = newValue
        }

        if let newType = updateRequest.valueType {
            let valueToValidate = updateRequest.value ?? entry.value
            try validateValueType(value: valueToValidate, type: newType)
            entry.valueType = newType.rawValue
        }

        if let newDescription = updateRequest.description {
            entry.description = newDescription
        }

        try await repository.update(entry)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Update.Response(
            id: entry.id!,
            key: entry.key,
            value: entry.value,
            valueType: entry.parsedValueType,
            description: entry.description,
            updatedAt: entry.updatedAt
        )
    }

    func delete(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid ID format")
        }

        let repository = req.repositories.remoteConfig
        guard let entry = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration entry not found")
        }

        try await repository.delete(entry)

        // Invalidate cache
        try await invalidateCache(req)

        return RemoteConfig.Delete.Response(
            message: "Configuration entry deleted successfully"
        )
    }

    // MARK: - Private Helpers

    private func buildConfigResponse(from entries: [RemoteConfigEntryModel]) -> RemoteConfig.Response {
        var featureFlags: [String: Bool] = [:]
        var settings: [String: AnyCodable] = [:]

        for entry in entries {
            switch entry.parsedValueType {
            case .boolean:
                featureFlags[entry.key] = entry.value.lowercased() == "true"
            case .integer:
                if let intValue = Int(entry.value) {
                    settings[entry.key] = AnyCodable(intValue)
                }
            case .string:
                settings[entry.key] = AnyCodable(entry.value)
            case .json:
                if let data = entry.value.data(using: .utf8),
                   let jsonValue = try? JSONSerialization.jsonObject(with: data) {
                    settings[entry.key] = AnyCodable(jsonValue)
                }
            }
        }

        // Generate version based on entry count and latest update
        let latestUpdate = entries.compactMap { $0.updatedAt ?? $0.createdAt }.max()
        let version = latestUpdate.map { "\(Int($0.timeIntervalSince1970))" } ?? "0"

        return RemoteConfig.Response(
            featureFlags: featureFlags,
            settings: settings,
            version: version
        )
    }

    private func validateValueType(value: String, type: RemoteConfig.ValueType) throws {
        switch type {
        case .boolean:
            let lowercased = value.lowercased()
            guard lowercased == "true" || lowercased == "false" else {
                throw Abort(.badRequest, reason: "Value must be 'true' or 'false' for boolean type")
            }
        case .integer:
            guard Int(value) != nil else {
                throw Abort(.badRequest, reason: "Value must be a valid integer")
            }
        case .string:
            // All strings are valid
            break
        case .json:
            guard let data = value.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                throw Abort(.badRequest, reason: "Value must be valid JSON")
            }
        }
    }

    private func invalidateCache(_ req: Request) async throws {
        try await req.application.cacheService.delete(Self.cacheKey)
    }
}

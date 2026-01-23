import Fluent
import Vapor

struct RemoteConfigController {

    func getConfig(_ req: Request) async throws -> RemoteConfig.Get.Response {
        let cacheService = req.application.remoteConfigCacheService
        let repository = req.repositories.remoteConfigs
        return try await cacheService.getConfig(using: repository)
    }

    func createConfig(_ req: Request) async throws -> RemoteConfig.Create.Response {
        let createRequest = try req.content.decode(RemoteConfig.Create.Request.self)

        // Validate the value matches the declared type
        try validateValue(createRequest.value, for: createRequest.valueType)

        let repository = req.repositories.remoteConfigs

        // Check if key already exists
        if try await repository.find(key: createRequest.key) != nil {
            throw Abort(.conflict, reason: "Configuration key '\(createRequest.key)' already exists")
        }

        let model = RemoteConfigModel(
            key: createRequest.key,
            value: createRequest.value,
            valueType: createRequest.valueType,
            category: createRequest.category
        )

        do {
            try await repository.create(model)
        } catch let error as DatabaseError where error.isConstraintFailure {
            // Handle race condition: concurrent creates may pass the check but fail at DB level
            throw Abort(.conflict, reason: "Configuration key '\(createRequest.key)' already exists")
        }

        // Invalidate cache after modification
        try await req.application.remoteConfigCacheService.invalidateCache()

        return model.toCreateResponse()
    }

    func updateConfig(_ req: Request) async throws -> RemoteConfig.Update.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid configuration ID")
        }

        let updateRequest = try req.content.decode(RemoteConfig.Update.Request.self)
        let repository = req.repositories.remoteConfigs

        guard let model = try await repository.find(id: id) else {
            throw Abort(.notFound, reason: "Configuration not found")
        }

        // Update fields if provided
        if let value = updateRequest.value {
            let typeToValidate = updateRequest.valueType ?? model.valueType
            try validateValue(value, for: typeToValidate)
            model.value = value
        }

        if let valueType = updateRequest.valueType {
            // If changing type without providing a new value, validate existing value against new type
            if updateRequest.value == nil {
                try validateValue(model.value, for: valueType)
            }
            model.valueType = valueType
        }

        try await repository.update(model)

        // Invalidate cache after modification
        try await req.application.remoteConfigCacheService.invalidateCache()

        return model.toUpdateResponse()
    }

    func deleteConfig(_ req: Request) async throws -> RemoteConfig.Delete.Response {
        guard let idString = req.parameters.get("id"),
              let id = UUID(uuidString: idString) else {
            throw Abort(.badRequest, reason: "Invalid configuration ID")
        }

        let repository = req.repositories.remoteConfigs

        guard try await repository.find(id: id) != nil else {
            throw Abort(.notFound, reason: "Configuration not found")
        }

        try await repository.delete(id: id)

        // Invalidate cache after modification
        try await req.application.remoteConfigCacheService.invalidateCache()

        return RemoteConfig.Delete.Response(
            success: true,
            message: "Configuration deleted successfully"
        )
    }

    // MARK: - Private Helpers

    private func validateValue(_ value: String, for type: RemoteConfigValueType) throws {
        switch type {
        case .boolean:
            let lowercased = value.lowercased()
            guard lowercased == "true" || lowercased == "false" || value == "1" || value == "0" else {
                throw Abort(.badRequest, reason: "Invalid boolean value. Use 'true', 'false', '1', or '0'")
            }
        case .integer:
            guard Int(value) != nil else {
                throw Abort(.badRequest, reason: "Invalid integer value")
            }
        case .string:
            // Any string is valid
            break
        }
    }
}

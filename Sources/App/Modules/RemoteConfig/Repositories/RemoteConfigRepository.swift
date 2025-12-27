import Fluent
import Vapor

protocol RemoteConfigRepositoryProtocol: Sendable {
    func getAllConfig() async throws -> [ConfigEntryModel]
    func getConfig(key: String) async throws -> ConfigEntryModel?
    func setConfig(key: String, value: Any, type: ConfigValueType) async throws -> ConfigEntryModel
    func deleteConfig(key: String) async throws
}

struct DatabaseRemoteConfigRepository: RemoteConfigRepositoryProtocol {
    let database: Database

    init(database: Database) {
        self.database = database
    }

    func getAllConfig() async throws -> [ConfigEntryModel] {
        try await ConfigEntryModel.query(on: database).all()
    }

    func getConfig(key: String) async throws -> ConfigEntryModel? {
        try await ConfigEntryModel.query(on: database)
            .filter(\.$key == key)
            .first()
    }

    func setConfig(key: String, value: Any, type: ConfigValueType) async throws -> ConfigEntryModel {
        // Validate type match before storing
        switch type {
        case .boolean:
            guard value is Bool else {
                throw Abort(.badRequest, reason: "Type mismatch: expected Bool, got \(Swift.type(of: value))")
            }
        case .integer:
            guard value is Int else {
                throw Abort(.badRequest, reason: "Type mismatch: expected Int, got \(Swift.type(of: value))")
            }
        case .string:
            guard value is String else {
                throw Abort(.badRequest, reason: "Type mismatch: expected String, got \(Swift.type(of: value))")
            }
        case .json:
            // JSON can be any encodable type, so skip validation
            break
        }

        // Check if config already exists
        if let existing = try await getConfig(key: key) {
            // Update existing config
            existing.valueType = type.rawValue
            existing.boolValue = nil
            existing.intValue = nil
            existing.stringValue = nil
            existing.jsonValue = nil

            switch type {
            case .boolean:
                existing.boolValue = value as? Bool
            case .integer:
                existing.intValue = value as? Int
            case .string:
                existing.stringValue = value as? String
            case .json:
                do {
                    let jsonData = try JSONEncoder().encode(AnyCodable(value))
                    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                        throw Abort(.internalServerError, reason: "Failed to encode JSON value to string")
                    }
                    existing.jsonValue = jsonString
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to encode JSON value: \(error.localizedDescription)")
                }
            }

            try await existing.update(on: database)
            return existing
        } else {
            // Create new config
            let entry = ConfigEntryModel(key: key, valueType: type.rawValue)

            switch type {
            case .boolean:
                entry.boolValue = value as? Bool
            case .integer:
                entry.intValue = value as? Int
            case .string:
                entry.stringValue = value as? String
            case .json:
                do {
                    let jsonData = try JSONEncoder().encode(AnyCodable(value))
                    guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                        throw Abort(.internalServerError, reason: "Failed to encode JSON value to string")
                    }
                    entry.jsonValue = jsonString
                } catch {
                    throw Abort(.internalServerError, reason: "Failed to encode JSON value: \(error.localizedDescription)")
                }
            }

            try await entry.save(on: database)
            return entry
        }
    }

    func deleteConfig(key: String) async throws {
        guard let entry = try await getConfig(key: key) else {
            return
        }
        try await entry.delete(on: database)
    }
}

extension Request {
    var remoteConfigRepository: RemoteConfigRepositoryProtocol {
        DatabaseRemoteConfigRepository(database: db)
    }
}

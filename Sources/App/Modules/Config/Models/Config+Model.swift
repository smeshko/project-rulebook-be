import Vapor

enum Config {
    // MARK: - Public Response

    struct Response: Content {
        let featureFlags: [String: Bool]
        let settings: [String: AnyCodable]
        let version: String

        static func from(entries: [ConfigEntryModel]) -> Response {
            var featureFlags: [String: Bool] = [:]
            var settings: [String: AnyCodable] = [:]

            for entry in entries {
                if entry.type == "boolean" {
                    featureFlags[entry.key] = entry.boolValue ?? false
                } else {
                    settings[entry.key] = entry.anyValue
                }
            }

            return Response(
                featureFlags: featureFlags,
                settings: settings,
                version: "1.0.0"
            )
        }
    }

    // MARK: - Admin Models

    enum Admin {
        struct ListResponse: Content {
            let entries: [ConfigEntryResponse]
        }

        struct CreateRequest: Content {
            let key: String
            let value: String
            let type: String
        }

        struct UpdateRequest: Content {
            let value: String
            let type: String?
        }

        struct ConfigEntryResponse: Content {
            let id: UUID
            let key: String
            let value: String
            let type: String
            let createdAt: Date?
            let updatedAt: Date?

            static func from(_ model: ConfigEntryModel) -> ConfigEntryResponse {
                ConfigEntryResponse(
                    id: model.id!,
                    key: model.key,
                    value: model.value,
                    type: model.type,
                    createdAt: model.createdAt,
                    updatedAt: model.updatedAt
                )
            }
        }

        struct DeleteResponse: Content {
            let message: String
        }
    }
}

// MARK: - AnyCodable Helper

/// A type-erased Codable wrapper for storing any JSON value
struct AnyCodable: Codable, Sendable {
    let value: any Sendable

    init(_ value: any Sendable) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = ()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [any Sendable]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: any Sendable]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

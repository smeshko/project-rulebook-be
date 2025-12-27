import Vapor

enum RemoteConfig {
    enum Entry {
        struct Response: Content {
            let featureFlags: [String: AnyCodable]
            let settings: [String: AnyCodable]
            let version: String
        }
    }

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: String
            let version: Int?
            let isActive: Bool?

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty)
                validations.add("value", as: String.self, is: !.empty)
                validations.add("valueType", as: String.self, is: .in("boolean", "integer", "string", "json"))
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let message: String
        }
    }

    enum Update {
        struct Request: Content, Validatable {
            let value: String?
            let valueType: String?
            let version: Int?
            let isActive: Bool?

            static func validations(_ validations: inout Validations) {
                validations.add("valueType", as: String?.self, is: .nil || !.nil && .in("boolean", "integer", "string", "json"), required: false)
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let message: String
        }
    }

    enum Delete {
        struct Response: Content {
            let message: String
        }
    }
}

// Helper for encoding dynamic JSON values
struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let string as String:
            try container.encode(string)
        case let dict as [String: AnyCodable]:
            try container.encode(dict)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
}

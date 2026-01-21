import Vapor

enum RemoteConfig {

    // MARK: - Value Types

    enum ValueType: String, Codable, CaseIterable, Sendable {
        case boolean
        case integer
        case string
        case json
    }

    // MARK: - Public Config Response

    struct Response: Content {
        let featureFlags: [String: Bool]
        let settings: [String: AnyCodable]
        let version: String
    }

    // MARK: - Admin CRUD

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: ValueType
            let description: String?

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty)
                validations.add("value", as: String.self, is: !.empty)
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: ValueType
            let description: String?
            let createdAt: Date?
        }
    }

    enum Update {
        struct Request: Content {
            let value: String?
            let valueType: ValueType?
            let description: String?
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: ValueType
            let description: String?
            let updatedAt: Date?
        }
    }

    enum List {
        struct Response: Content {
            let entries: [Entry]
            let total: Int
        }

        struct Entry: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: ValueType
            let description: String?
            let createdAt: Date?
            let updatedAt: Date?
        }
    }

    enum Detail {
        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: ValueType
            let description: String?
            let createdAt: Date?
            let updatedAt: Date?
        }
    }

    enum Delete {
        struct Response: Content {
            let message: String
        }
    }
}

// MARK: - AnyCodable Type-Erased Wrapper

struct AnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unable to decode AnyCodable"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "Unable to encode AnyCodable"
                )
            )
        }
    }
}

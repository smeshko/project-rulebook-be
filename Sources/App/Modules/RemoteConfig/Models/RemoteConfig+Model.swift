import Vapor

enum RemoteConfig {

    // MARK: - Value Types

    enum ValueType: String, Codable, CaseIterable {
        case boolean
        case integer
        case string
        case json
    }

    // MARK: - Public Config Response

    enum Public {
        struct Response: Content {
            let featureFlags: [String: Bool]
            let settings: [String: AnyCodable]
            let version: Date
        }
    }

    // MARK: - Admin CRUD Types

    enum List {
        struct Response: Content {
            let entries: [Entry]
            let count: Int
        }

        struct Entry: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
            let description: String?
            let createdAt: Date?
            let updatedAt: Date?
        }
    }

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: String
            let description: String?

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty && .count(1...128) && .pattern("^[a-zA-Z][a-zA-Z0-9_]*$"))
                validations.add("value", as: String.self, is: !.empty)
                validations.add("valueType", as: String.self, is: .in("boolean", "integer", "string", "json"))
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
            let description: String?
            let createdAt: Date?
            let message: String
        }
    }

    enum Update {
        struct Request: Content, Validatable {
            let value: String?
            let valueType: String?
            let description: String?

            static func validations(_ validations: inout Validations) {
                // valueType is optional but if provided must be valid
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
            let description: String?
            let updatedAt: Date?
            let message: String
        }
    }

    enum Delete {
        struct Response: Content {
            let key: String
            let message: String
        }
    }
}

// MARK: - AnyCodable for Heterogeneous Settings

/// A type-erased Codable wrapper for handling heterogeneous JSON values
struct AnyCodable: @unchecked Sendable, Codable, Equatable {
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
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode AnyCodable")
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
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unable to encode AnyCodable"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case is (NSNull, NSNull):
            return true
        case let (lhs as Bool, rhs as Bool):
            return lhs == rhs
        case let (lhs as Int, rhs as Int):
            return lhs == rhs
        case let (lhs as Double, rhs as Double):
            return lhs == rhs
        case let (lhs as String, rhs as String):
            return lhs == rhs
        default:
            return false
        }
    }
}

import Vapor

enum RemoteConfig {

    /// Response model for public config endpoint
    struct Response: Content {
        let featureFlags: [String: Bool]
        let settings: [String: AnyCodable]
        let version: String
    }

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
            let updatedAt: Date?
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
            let createdAt: Date?
            let updatedAt: Date?
        }
    }

    enum List {
        struct Response: Content {
            let items: [Item]
            let total: Int
        }

        struct Item: Content {
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

    enum ValueType: String, Content {
        case boolean
        case integer
        case string
        case json
    }
}

/// Type-erased Codable wrapper for heterogeneous settings values
/// Uses @unchecked Sendable because the underlying value is immutable after initialization
struct AnyCodable: Codable, Equatable, @unchecked Sendable {
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
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode value")
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
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode value"))
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (lhsBool as Bool, rhsBool as Bool):
            return lhsBool == rhsBool
        case let (lhsInt as Int, rhsInt as Int):
            return lhsInt == rhsInt
        case let (lhsDouble as Double, rhsDouble as Double):
            return lhsDouble == rhsDouble
        case let (lhsString as String, rhsString as String):
            return lhsString == rhsString
        default:
            return false
        }
    }
}

import Vapor

/// Remote configuration request/response models organized by operation.
enum RemoteConfig {

    // MARK: - Public Endpoint

    enum Get {
        /// Response for the public config endpoint.
        /// Groups configuration values by category (featureFlags, settings).
        struct Response: Content {
            let featureFlags: [String: Bool]
            let settings: [String: AnyCodableValue]
        }
    }

    // MARK: - Admin Endpoints

    enum List {
        /// Response for listing all configuration entries with metadata.
        struct Response: Content {
            let entries: [Entry]
        }

        struct Entry: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
            let createdAt: Date?
            let updatedAt: Date?
        }
    }

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: String

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty)
                validations.add("value", as: String.self, is: !.empty)
                validations.add("valueType", as: String.self, is: .in("boolean", "integer", "string"))
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
            let message: String
        }
    }

    enum Update {
        struct Request: Content, Validatable {
            let value: String
            let valueType: String?

            static func validations(_ validations: inout Validations) {
                validations.add("value", as: String.self, is: !.empty)
                // Validate valueType if provided (optional field)
                validations.add("valueType", as: String?.self, is: .nil || .in("boolean", "integer", "string"), required: false)
            }
        }

        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: String
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

// MARK: - Type-Erased Codable Value

/// A type-erased codable value that can hold any JSON-compatible value.
/// Used for settings which can be integers or strings.
enum AnyCodableValue: Codable, Equatable {
    case int(Int)
    case string(String)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Int, Bool, or String"
                )
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

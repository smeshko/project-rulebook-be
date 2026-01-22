import Vapor

enum RemoteConfig {

    // MARK: - GET /api/v1/config (Public)

    enum Get {
        /// Response for public config endpoint.
        /// Transforms flat config into nested featureFlags/settings structure.
        struct Response: Content {
            let featureFlags: [String: AnyCodable]
            let settings: [String: AnyCodable]

            enum CodingKeys: String, CodingKey {
                case featureFlags = "feature_flags"
                case settings
            }
        }
    }

    // MARK: - POST /api/v1/config (Admin)

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: String
            let category: String

            enum CodingKeys: String, CodingKey {
                case key
                case value
                case valueType = "value_type"
                case category
            }

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty)
                validations.add("value", as: String.self, is: !.empty)
                validations.add("value_type", as: String.self, is: .in("boolean", "integer", "string"))
                validations.add("category", as: String.self, is: .in("feature_flags", "settings"))
            }
        }

        struct Response: Content {
            let message: String
            let config: ConfigItem

            enum CodingKeys: String, CodingKey {
                case message
                case config
            }
        }
    }

    // MARK: - PATCH /api/v1/config/:key (Admin)

    enum Update {
        struct Request: Content, Validatable {
            let value: String
            let valueType: String?

            enum CodingKeys: String, CodingKey {
                case value
                case valueType = "value_type"
            }

            static func validations(_ validations: inout Validations) {
                validations.add("value", as: String.self, is: !.empty)
            }
        }

        struct Response: Content {
            let message: String
            let config: ConfigItem

            enum CodingKeys: String, CodingKey {
                case message
                case config
            }
        }
    }

    // MARK: - DELETE /api/v1/config/:key (Admin)

    enum Delete {
        struct Response: Content {
            let message: String
            let deleted: Bool

            enum CodingKeys: String, CodingKey {
                case message
                case deleted
            }
        }
    }

    // MARK: - Admin List (Admin)

    enum List {
        struct Response: Content {
            let configs: [ConfigItem]
            let count: Int

            enum CodingKeys: String, CodingKey {
                case configs
                case count
            }
        }
    }

    // MARK: - Shared Types

    struct ConfigItem: Content {
        let id: UUID
        let key: String
        let value: String
        let valueType: String
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case key
            case value
            case valueType = "value_type"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
}

// MARK: - AnyCodable Helper

/// Type-erased Codable wrapper for dynamic JSON values.
/// Used to support mixed-type configuration values (boolean, integer, string).
/// @unchecked Sendable because internal value types (Bool, Int, Double, String) are all Sendable.
struct AnyCodable: @unchecked Sendable, Codable, Equatable {
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
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Bool, r as Bool): return l == r
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        default: return false
        }
    }
}

import Foundation
import Vapor

public enum RemoteConfig {}

public extension RemoteConfig {
    enum Get {
        public struct Response: Content, Equatable, Sendable {
            public let featureFlags: [String: AnyCodableValue]
            public let settings: [String: AnyCodableValue]

            public init(
                featureFlags: [String: AnyCodableValue],
                settings: [String: AnyCodableValue]
            ) {
                self.featureFlags = featureFlags
                self.settings = settings
            }

            enum CodingKeys: String, CodingKey {
                case featureFlags = "feature_flags"
                case settings
            }
        }
    }

    enum Create {
        public struct Request: Content, Equatable, Sendable {
            public let key: String
            public let value: String
            public let valueType: String
            public let category: String

            public init(
                key: String,
                value: String,
                valueType: String,
                category: String
            ) {
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
            }

            enum CodingKeys: String, CodingKey {
                case key
                case value
                case valueType = "value_type"
                case category
            }
        }

        public struct Response: Content, Equatable, Sendable {
            public let id: UUID
            public let key: String
            public let value: String
            public let valueType: String
            public let category: String
            public let createdAt: Date?

            public init(
                id: UUID,
                key: String,
                value: String,
                valueType: String,
                category: String,
                createdAt: Date?
            ) {
                self.id = id
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
                self.createdAt = createdAt
            }

            enum CodingKeys: String, CodingKey {
                case id
                case key
                case value
                case valueType = "value_type"
                case category
                case createdAt = "created_at"
            }
        }
    }

    enum Update {
        public struct Request: Content, Equatable, Sendable {
            public let value: String?

            public init(value: String? = nil) {
                self.value = value
            }
        }

        public struct Response: Content, Equatable, Sendable {
            public let id: UUID
            public let key: String
            public let value: String
            public let valueType: String
            public let category: String
            public let updatedAt: Date?

            public init(
                id: UUID,
                key: String,
                value: String,
                valueType: String,
                category: String,
                updatedAt: Date?
            ) {
                self.id = id
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
                self.updatedAt = updatedAt
            }

            enum CodingKeys: String, CodingKey {
                case id
                case key
                case value
                case valueType = "value_type"
                case category
                case updatedAt = "updated_at"
            }
        }
    }

    enum Delete {
        public struct Response: Content, Equatable, Sendable {
            public let key: String
            public let deleted: Bool
            public let timestamp: Date

            public init(
                key: String,
                deleted: Bool,
                timestamp: Date
            ) {
                self.key = key
                self.deleted = deleted
                self.timestamp = timestamp
            }
        }
    }
}

/// A type-erased Codable value that can represent boolean, integer, or string values
public enum AnyCodableValue: Codable, Equatable, Sendable {
    case boolean(Bool)
    case integer(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected boolean, integer, or string"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .boolean(let value):
            try container.encode(value)
        case .integer(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

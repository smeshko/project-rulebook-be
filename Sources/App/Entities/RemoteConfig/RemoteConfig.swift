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
        }
    }

    enum Create {
        public struct Request: Content, Equatable, Sendable {
            public let key: String
            public let value: String
            public let valueType: RemoteConfigValueType
            public let category: RemoteConfigCategory

            public init(
                key: String,
                value: String,
                valueType: RemoteConfigValueType,
                category: RemoteConfigCategory
            ) {
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
            }
        }

        public struct Response: Content, Equatable, Sendable {
            public let id: UUID
            public let key: String
            public let value: String
            public let valueType: RemoteConfigValueType
            public let category: RemoteConfigCategory
            public let createdAt: Date?

            public init(
                id: UUID,
                key: String,
                value: String,
                valueType: RemoteConfigValueType,
                category: RemoteConfigCategory,
                createdAt: Date?
            ) {
                self.id = id
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
                self.createdAt = createdAt
            }
        }
    }

    enum Update {
        public struct Request: Content, Equatable, Sendable {
            public let value: String?
            public let valueType: RemoteConfigValueType?

            public init(
                value: String? = nil,
                valueType: RemoteConfigValueType? = nil
            ) {
                self.value = value
                self.valueType = valueType
            }
        }

        public struct Response: Content, Equatable, Sendable {
            public let id: UUID
            public let key: String
            public let value: String
            public let valueType: RemoteConfigValueType
            public let category: RemoteConfigCategory
            public let updatedAt: Date?

            public init(
                id: UUID,
                key: String,
                value: String,
                valueType: RemoteConfigValueType,
                category: RemoteConfigCategory,
                updatedAt: Date?
            ) {
                self.id = id
                self.key = key
                self.value = value
                self.valueType = valueType
                self.category = category
                self.updatedAt = updatedAt
            }
        }
    }

    enum Delete {
        public struct Response: Content, Equatable, Sendable {
            public let success: Bool
            public let message: String

            public init(success: Bool, message: String) {
                self.success = success
                self.message = message
            }
        }
    }
}

/// A type-erased Codable value for storing different types in the config response
public enum AnyCodableValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case string(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected Bool, Int, or String"
                )
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        }
    }
}

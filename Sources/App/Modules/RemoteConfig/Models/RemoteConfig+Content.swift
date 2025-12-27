import Vapor
import Foundation

enum RemoteConfig {
    // Value wrapper that includes type information for clients
    struct ConfigValue: Content, Sendable {
        let value: String
        let type: ConfigValueType
    }

    // Codable-safe value wrapper that can represent any JSON type
    enum AnyCodableValue: Codable, Sendable {
        case bool(Bool)
        case int(Int)
        case string(String)
        case object([String: AnyCodableValue])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let bool = try? container.decode(Bool.self) {
                self = .bool(bool)
            } else if let int = try? container.decode(Int.self) {
                self = .int(int)
            } else if let string = try? container.decode(String.self) {
                self = .string(string)
            } else if let object = try? container.decode([String: AnyCodableValue].self) {
                self = .object(object)
            } else {
                throw DecodingError.typeMismatch(
                    AnyCodableValue.self,
                    DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
                )
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .bool(let value):
                try container.encode(value)
            case .int(let value):
                try container.encode(value)
            case .string(let value):
                try container.encode(value)
            case .object(let value):
                try container.encode(value)
            }
        }
    }

    // Public GET response - matches acceptance criteria structure
    // Fully Codable-compliant for caching
    struct GetResponse: Content, Sendable {
        let featureFlags: [String: AnyCodableValue]
        let settings: [String: AnyCodableValue]
        let version: String

        init(featureFlags: [String: AnyCodableValue], settings: [String: AnyCodableValue], version: String) {
            self.featureFlags = featureFlags
            self.settings = settings
            self.version = version
        }
    }

    // Admin update request
    struct UpdateRequest: Content, Sendable {
        let key: String
        let value: String
        let type: ConfigValueType
    }

    // Admin update response
    struct UpdateResponse: Content, Sendable {
        let success: Bool
        let key: String
        let message: String
    }
}

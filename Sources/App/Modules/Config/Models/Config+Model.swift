import Vapor

enum Config {

    // MARK: - Public Response

    struct Response: Content {
        let featureFlags: [String: Bool]
        let settings: [String: AnyCodableValue]
        let version: String

        init(featureFlags: [String: Bool] = [:], settings: [String: AnyCodableValue] = [:], version: String = "1.0.0") {
            self.featureFlags = featureFlags
            self.settings = settings
            self.version = version
        }

        init(from models: [ConfigValueModel]) {
            var featureFlags: [String: Bool] = [:]
            var settings: [String: AnyCodableValue] = [:]
            var version = "1.0.0"

            for model in models {
                let key = model.key

                // Handle special keys
                if key == "version" {
                    version = model.value
                    continue
                }

                // Handle feature flags (keys starting with "featureFlags.")
                if key.hasPrefix("featureFlags.") {
                    let flagName = String(key.dropFirst("featureFlags.".count))
                    featureFlags[flagName] = model.value.lowercased() == "true"
                    continue
                }

                // Handle settings (keys starting with "settings.")
                if key.hasPrefix("settings.") {
                    let settingName = String(key.dropFirst("settings.".count))
                    settings[settingName] = model.decodedValue
                    continue
                }
            }

            self.featureFlags = featureFlags
            self.settings = settings
            self.version = version
        }
    }

    // MARK: - Admin Update

    enum Update {
        struct Request: Content {
            let items: [ConfigItem]
        }

        struct ConfigItem: Content {
            let key: String
            let value: String
            let valueType: ValueType
        }
    }

    // MARK: - Value Types

    enum ValueType: String, Content {
        case boolean
        case integer
        case string
        case json
    }
}

// MARK: - AnyCodableValue

/// A type-erasing wrapper for JSON-compatible values
enum AnyCodableValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([AnyCodableValue])
    case object([String: AnyCodableValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([AnyCodableValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: AnyCodableValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    static func from(_ string: String, type: Config.ValueType) -> AnyCodableValue {
        switch type {
        case .boolean:
            return .bool(string.lowercased() == "true")
        case .integer:
            return .int(Int(string) ?? 0)
        case .string:
            return .string(string)
        case .json:
            guard let data = string.data(using: .utf8),
                  let value = try? JSONDecoder().decode(AnyCodableValue.self, from: data) else {
                return .string(string)
            }
            return value
        }
    }
}

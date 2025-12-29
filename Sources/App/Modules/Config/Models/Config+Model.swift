import Vapor

enum Config {

    // MARK: - Response Types

    struct Response: Content {
        let featureFlags: [String: Bool]
        let settings: [String: SettingValue]
        let version: String
    }

    enum SettingValue: Codable, Equatable, Sendable {
        case bool(Bool)
        case int(Int)
        case string(String)
        case object([String: AnyCodable])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
                return
            }

            if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
                return
            }

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
                return
            }

            if let objectValue = try? container.decode([String: AnyCodable].self) {
                self = .object(objectValue)
                return
            }

            throw DecodingError.typeMismatch(
                SettingValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode SettingValue"
                )
            )
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

    // MARK: - Update Types

    enum Update {
        struct Request: Content {
            let entries: [Entry]

            struct Entry: Content {
                let key: String
                let value: ConfigValue
                let valueType: String
            }
        }

        struct Response: Content {
            let updated: [String]
            let message: String
        }
    }
}

// MARK: - Config Value Type

struct ConfigValue: Codable, Equatable, Sendable {
    private let storage: Storage

    private enum Storage: Codable, Equatable, Sendable {
        case bool(Bool)
        case int(Int)
        case string(String)
        case object([String: AnyCodable])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let boolValue = try? container.decode(Bool.self) {
                self = .bool(boolValue)
                return
            }

            if let intValue = try? container.decode(Int.self) {
                self = .int(intValue)
                return
            }

            if let stringValue = try? container.decode(String.self) {
                self = .string(stringValue)
                return
            }

            if let objectValue = try? container.decode([String: AnyCodable].self) {
                self = .object(objectValue)
                return
            }

            throw DecodingError.typeMismatch(
                Storage.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unable to decode ConfigValue"
                )
            )
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

    init(bool: Bool) {
        self.storage = .bool(bool)
    }

    init(int: Int) {
        self.storage = .int(int)
    }

    init(string: String) {
        self.storage = .string(string)
    }

    init(object: [String: AnyCodable]) {
        self.storage = .object(object)
    }

    init(from decoder: Decoder) throws {
        self.storage = try Storage(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        try storage.encode(to: encoder)
    }

    var boolValue: Bool? {
        if case .bool(let value) = storage { return value }
        return nil
    }

    var intValue: Int? {
        if case .int(let value) = storage { return value }
        return nil
    }

    var stringValue: String? {
        if case .string(let value) = storage { return value }
        return nil
    }

    var objectValue: [String: AnyCodable]? {
        if case .object(let value) = storage { return value }
        return nil
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable, Equatable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
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

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull):
            return true
        case (let lhsBool as Bool, let rhsBool as Bool):
            return lhsBool == rhsBool
        case (let lhsInt as Int, let rhsInt as Int):
            return lhsInt == rhsInt
        case (let lhsDouble as Double, let rhsDouble as Double):
            return lhsDouble == rhsDouble
        case (let lhsString as String, let rhsString as String):
            return lhsString == rhsString
        default:
            return false
        }
    }
}

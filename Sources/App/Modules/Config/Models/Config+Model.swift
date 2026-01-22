import Vapor

enum Config {
    enum Get {
        struct Response: Content {
            let featureFlags: [String: ConfigValue]
            let settings: [String: ConfigValue]
        }
    }

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: ConfigValueType
            let category: ConfigCategory

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty && .count(1...255))
                validations.add("value", as: String.self, is: !.empty)
            }
        }
    }

    enum Update {
        struct Request: Content, Validatable {
            let value: String?
            let valueType: ConfigValueType?
            let category: ConfigCategory?

            static func validations(_ validations: inout Validations) {
                validations.add("value", as: String?.self, is: .nil || !.empty, required: false)
            }
        }
    }

    enum Entry {
        struct Response: Content {
            let id: UUID
            let key: String
            let value: ConfigValue
            let valueType: ConfigValueType
            let category: ConfigCategory
            let createdAt: Date?
            let updatedAt: Date?

            init(from model: ConfigEntryModel) throws {
                self.id = try model.requireID()
                self.key = model.key
                self.value = ConfigValue.from(rawValue: model.value, type: model.valueType)
                self.valueType = model.valueType
                self.category = model.category
                self.createdAt = model.createdAt
                self.updatedAt = model.updatedAt
            }
        }
    }

    enum List {
        struct Response: Content {
            let entries: [Entry.Response]
        }
    }
}

enum ConfigValue: Content, Equatable {
    case boolean(Bool)
    case integer(Int)
    case string(String)

    static func from(rawValue: String, type: ConfigValueType) -> ConfigValue {
        switch type {
        case .boolean:
            return .boolean(rawValue.lowercased() == "true")
        case .integer:
            return .integer(Int(rawValue) ?? 0)
        case .string:
            return .string(rawValue)
        }
    }

    static func validate(rawValue: String, type: ConfigValueType) -> Bool {
        switch type {
        case .boolean:
            let lowercased = rawValue.lowercased()
            return lowercased == "true" || lowercased == "false"
        case .integer:
            return Int(rawValue) != nil
        case .string:
            return true
        }
    }

    func encode(to encoder: Encoder) throws {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                ConfigValue.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected boolean, integer, or string"
                )
            )
        }
    }
}

import Vapor

/// DTO namespace for Remote Configuration endpoints.
enum RemoteConfig {

    // MARK: - GET /api/v1/config (Public Endpoint)

    enum Get {
        /// Response structure for the public config endpoint.
        ///
        /// Groups configuration by category: feature flags and settings.
        /// Values are typed according to their valueType in storage.
        struct Response: Content {
            let featureFlags: [String: AnyCodableValue]
            let settings: [String: AnyCodableValue]
        }
    }

    // MARK: - POST /api/v1/config (Admin Only)

    enum Create {
        struct Request: Content, Validatable {
            let key: String
            let value: String
            let valueType: RemoteConfigValueType
            let category: RemoteConfigCategory

            static func validations(_ validations: inout Validations) {
                validations.add("key", as: String.self, is: !.empty && .count(1...100))
                validations.add("value", as: String.self, is: !.empty)
            }

            /// Validates that the value can be parsed according to the declared valueType.
            func validateValueMatchesType() throws {
                switch valueType {
                case .boolean:
                    let lowercased = value.lowercased()
                    guard lowercased == "true" || lowercased == "false" || value == "1" || value == "0" else {
                        throw Abort(.badRequest, reason: "Invalid boolean value '\(value)'. Expected 'true', 'false', '1', or '0'.")
                    }
                case .integer:
                    guard Int(value) != nil else {
                        throw Abort(.badRequest, reason: "Invalid integer value '\(value)'. Expected a valid integer.")
                    }
                case .string:
                    break
                }
            }
        }
    }

    // MARK: - PATCH /api/v1/config/:key (Admin Only)

    enum Update {
        struct Request: Content, Validatable {
            let value: String?
            let valueType: RemoteConfigValueType?
            let category: RemoteConfigCategory?

            static func validations(_ validations: inout Validations) {
                // Optional fields - type validation done in validateValueMatchesType
            }

            /// Validates that if both value and valueType are provided, they are compatible.
            /// If only valueType is provided, validation must be done against existing value in controller.
            func validateValueMatchesType(existingValue: String? = nil) throws {
                guard let type = valueType else { return }

                let valueToCheck = value ?? existingValue
                guard let valueToCheck else { return }

                switch type {
                case .boolean:
                    let lowercased = valueToCheck.lowercased()
                    guard lowercased == "true" || lowercased == "false" || valueToCheck == "1" || valueToCheck == "0" else {
                        throw Abort(.badRequest, reason: "Invalid boolean value '\(valueToCheck)'. Expected 'true', 'false', '1', or '0'.")
                    }
                case .integer:
                    guard Int(valueToCheck) != nil else {
                        throw Abort(.badRequest, reason: "Invalid integer value '\(valueToCheck)'. Expected a valid integer.")
                    }
                case .string:
                    break
                }
            }
        }
    }

    // MARK: - Item Response (used for Create/Update responses)

    enum Item {
        struct Response: Content {
            let id: UUID
            let key: String
            let value: String
            let valueType: RemoteConfigValueType
            let category: RemoteConfigCategory
            let createdAt: Date?
            let updatedAt: Date?

            init(from model: RemoteConfigModel) throws {
                self.id = try model.requireID()
                self.key = model.key
                self.value = model.value
                self.valueType = model.valueType
                self.category = model.category
                self.createdAt = model.createdAt
                self.updatedAt = model.updatedAt
            }
        }
    }
}

// MARK: - AnyCodableValue

/// A wrapper type to encode typed values (boolean, integer, string) in JSON.
enum AnyCodableValue: Codable, Equatable {
    case bool(Bool)
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
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

    /// Creates an AnyCodableValue from a string and value type.
    static func from(stringValue: String, type: RemoteConfigValueType) -> AnyCodableValue {
        switch type {
        case .boolean:
            let boolValue = stringValue.lowercased() == "true" || stringValue == "1"
            return .bool(boolValue)
        case .integer:
            return .int(Int(stringValue) ?? 0)
        case .string:
            return .string(stringValue)
        }
    }
}

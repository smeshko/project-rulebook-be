import Foundation

/// Property wrapper that validates values using specified validation rules.
///
/// @Validated provides a declarative way to add validation to properties,
/// ensuring values meet specified criteria before being set. It works with
/// the ValidationRule protocol to provide flexible, reusable validation logic.
///
/// ## Features
/// - **Automatic Validation**: Values are validated on assignment
/// - **Composable Rules**: Combine multiple validation rules
/// - **Error Collection**: Access all validation errors
/// - **Default Values**: Fallback to safe defaults on validation failure
///
/// ## Usage Examples
///
/// ### Basic Usage
/// ```swift
/// struct User {
///     @Validated(rules: [EmailRule()])
///     var email: String = ""
///     
///     @Validated(rules: [MinLengthRule(8), MaxLengthRule(100)])
///     var password: String = ""
///     
///     @Validated(rules: [RangeRule(1...120)])
///     var age: Int = 0
/// }
/// ```
///
/// ### Accessing Validation State
/// ```swift
/// let user = User()
/// user.email = "invalid"
/// 
/// if !user.$email.isValid {
///     print(user.$email.errors)  // ["Invalid email format"]
/// }
/// ```
///
/// ### Custom Validation
/// ```swift
/// @Validated(rules: [
///     CustomRule { value in
///         value.contains("@") ? .valid : .invalid("Must contain @")
///     }
/// ])
/// var username: String = ""
/// ```
@propertyWrapper
public struct Validated<Value> {
    /// The underlying value storage.
    private var value: Value
    
    /// The validation rules to apply.
    private let rules: [any ValidationRule<Value>]
    
    /// The last validation errors encountered.
    private var lastErrors: [String] = []
    
    /// The default value to use when validation fails (if specified).
    private let defaultValue: Value?
    
    /// The validation mode determining when validation occurs.
    private let mode: ValidationMode
    
    /// Creates a new Validated property wrapper.
    ///
    /// - Parameters:
    ///   - wrappedValue: The initial value
    ///   - rules: The validation rules to apply
    ///   - defaultValue: Optional default value when validation fails
    ///   - mode: The validation mode (default: .onChange)
    public init(
        wrappedValue: Value,
        rules: [any ValidationRule<Value>],
        defaultValue: Value? = nil,
        mode: ValidationMode = .onChange
    ) {
        self.value = wrappedValue
        self.rules = rules
        self.defaultValue = defaultValue
        self.mode = mode
        
        // Validate initial value if mode requires it
        if mode == .always {
            self.validate(wrappedValue)
        }
    }
    
    /// The wrapped value with validation.
    public var wrappedValue: Value {
        get { value }
        set {
            switch mode {
            case .onChange, .always:
                if validate(newValue) {
                    value = newValue
                } else if let defaultValue = defaultValue {
                    value = defaultValue
                }
                // If validation fails and no default, keep current value
            case .manual:
                // In manual mode, always set the value
                value = newValue
            }
        }
    }
    
    /// The projected value providing access to validation state.
    public var projectedValue: ValidationState<Value> {
        get {
            ValidationState(
                value: value,
                rules: rules,
                errors: lastErrors,
                isValid: lastErrors.isEmpty
            )
        }
        set {
            // Allow manual update of the value through projected value
            value = newValue.value
            lastErrors = newValue.errors
        }
    }
    
    /// Validates a value against all rules.
    ///
    /// - Parameter value: The value to validate
    /// - Returns: True if valid, false otherwise
    @discardableResult
    private mutating func validate(_ value: Value) -> Bool {
        var errors: [String] = []
        
        for rule in rules {
            let result = rule.validate(value)
            if let error = result.errorMessage {
                errors.append(error)
            }
        }
        
        lastErrors = errors
        return errors.isEmpty
    }
}

/// Validation mode determining when validation occurs.
public enum ValidationMode {
    /// Validate only when value changes (default).
    case onChange
    
    /// Always validate, including initial value.
    case always
    
    /// Manual validation only (value always set).
    case manual
}

/// State information for a validated property.
public struct ValidationState<Value> {
    /// The current value.
    public let value: Value
    
    /// The validation rules.
    public let rules: [any ValidationRule<Value>]
    
    /// Current validation errors.
    public var errors: [String]
    
    /// Whether the current value is valid.
    public var isValid: Bool
    
    /// Validates the current value.
    ///
    /// - Returns: ValidationResult for the current value
    public mutating func validate() -> ValidationResult {
        var allErrors: [String] = []
        
        for rule in rules {
            let result = rule.validate(value)
            if let error = result.errorMessage {
                allErrors.append(error)
            }
        }
        
        errors = allErrors
        isValid = allErrors.isEmpty
        
        if isValid {
            return .valid
        } else {
            return .invalid(allErrors.joined(separator: ", "))
        }
    }
    
    /// Creates a new state with a different value.
    ///
    /// - Parameter newValue: The new value
    /// - Returns: New ValidationState with the value
    public func with(value newValue: Value) -> ValidationState<Value> {
        var newState = ValidationState(
            value: newValue,
            rules: rules,
            errors: [],
            isValid: true
        )
        _ = newState.validate()
        return newState
    }
}

// MARK: - Codable Support

extension Validated: Codable where Value: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let decodedValue = try container.decode(Value.self)
        
        // Note: We can't restore rules from decoding, so we use empty rules
        // In practice, you'd typically set up the rules in the type's init
        self.init(wrappedValue: decodedValue, rules: [], mode: .manual)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - Equatable Support

extension Validated: Equatable where Value: Equatable {
    public static func == (lhs: Validated<Value>, rhs: Validated<Value>) -> Bool {
        lhs.value == rhs.value
    }
}

// MARK: - Hashable Support

extension Validated: Hashable where Value: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

// MARK: - Builder Pattern for Complex Validation

/// Builder for creating complex validated properties.
public struct ValidatedBuilder<Value> {
    private var rules: [any ValidationRule<Value>] = []
    private var defaultValue: Value?
    private var mode: ValidationMode = .onChange
    
    /// Creates a new builder.
    public init() {}
    
    /// Adds a validation rule.
    public func rule(_ rule: any ValidationRule<Value>) -> ValidatedBuilder<Value> {
        var builder = self
        builder.rules.append(rule)
        return builder
    }
    
    /// Adds multiple validation rules.
    public func rules(_ rules: any ValidationRule<Value>...) -> ValidatedBuilder<Value> {
        var builder = self
        builder.rules.append(contentsOf: rules)
        return builder
    }
    
    /// Sets the default value.
    public func defaultValue(_ value: Value) -> ValidatedBuilder<Value> {
        var builder = self
        builder.defaultValue = value
        return builder
    }
    
    /// Sets the validation mode.
    public func mode(_ mode: ValidationMode) -> ValidatedBuilder<Value> {
        var builder = self
        builder.mode = mode
        return builder
    }
    
    /// Builds the Validated property wrapper.
    public func build(wrappedValue: Value) -> Validated<Value> {
        Validated(
            wrappedValue: wrappedValue,
            rules: rules,
            defaultValue: defaultValue,
            mode: mode
        )
    }
}

// MARK: - Convenience Extensions

public extension Validated where Value == String {
    /// Creates a validated email property.
    static func email(_ value: String = "") -> Validated<String> {
        Validated(wrappedValue: value, rules: [EmailRule()])
    }
    
    /// Creates a validated password property.
    static func password(_ value: String = "", minLength: Int = 8) -> Validated<String> {
        Validated(wrappedValue: value, rules: [
            MinLengthRule(minLength, message: "Password must be at least \(minLength) characters"),
            PatternRule(
                pattern: "^(?=.*[A-Za-z])(?=.*\\d).+$",
                message: "Password must contain at least one letter and one number"
            )
        ])
    }
    
    /// Creates a validated username property.
    static func username(_ value: String = "", minLength: Int = 3, maxLength: Int = 20) -> Validated<String> {
        Validated(wrappedValue: value, rules: [
            MinLengthRule(minLength),
            MaxLengthRule(maxLength),
            PatternRule(
                pattern: "^[a-zA-Z0-9_-]+$",
                message: "Username can only contain letters, numbers, underscores, and hyphens"
            )
        ])
    }
}
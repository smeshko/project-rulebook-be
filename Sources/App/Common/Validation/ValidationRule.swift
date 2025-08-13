import Foundation

/// Protocol defining a validation rule for property validation.
///
/// ValidationRule provides a composable way to define validation logic
/// that can be reused across different properties and models. Rules can
/// be combined using logical operators for complex validation scenarios.
///
/// ## Key Features
/// - **Composable**: Rules can be combined using operators
/// - **Reusable**: Define once, use across multiple properties
/// - **Type-Safe**: Compile-time verification of value types
/// - **Descriptive**: Clear error messages for validation failures
///
/// ## Example Implementation
/// ```swift
/// struct MinLengthRule: ValidationRule {
///     let minLength: Int
///     
///     func validate(_ value: String) -> ValidationResult {
///         if value.count >= minLength {
///             return .valid
///         } else {
///             return .invalid("Must be at least \(minLength) characters")
///         }
///     }
/// }
/// ```
public protocol ValidationRule<Value> {
    /// The type of value this rule validates.
    associatedtype Value
    
    /// Validates the given value against this rule.
    ///
    /// - Parameter value: The value to validate
    /// - Returns: The validation result
    func validate(_ value: Value) -> ValidationResult
}

/// Result of a validation operation.
public enum ValidationResult: Sendable {
    /// The value is valid.
    case valid
    
    /// The value is invalid with an error message.
    case invalid(String)
    
    /// Checks if the result is valid.
    public var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    /// Gets the error message if invalid.
    public var errorMessage: String? {
        switch self {
        case .valid:
            return nil
        case .invalid(let message):
            return message
        }
    }
}

// MARK: - Common Validation Rules

/// Validates that a string is not empty.
public struct NotEmptyRule: ValidationRule {
    public init() {}
    
    public func validate(_ value: String) -> ValidationResult {
        if value.isEmpty {
            return .invalid("Value cannot be empty")
        }
        return .valid
    }
}

/// Validates minimum length for strings.
public struct MinLengthRule: ValidationRule {
    public let minLength: Int
    public let message: String?
    
    public init(_ minLength: Int, message: String? = nil) {
        self.minLength = minLength
        self.message = message
    }
    
    public func validate(_ value: String) -> ValidationResult {
        if value.count >= minLength {
            return .valid
        }
        return .invalid(message ?? "Must be at least \(minLength) characters long")
    }
}

/// Validates maximum length for strings.
public struct MaxLengthRule: ValidationRule {
    public let maxLength: Int
    public let message: String?
    
    public init(_ maxLength: Int, message: String? = nil) {
        self.maxLength = maxLength
        self.message = message
    }
    
    public func validate(_ value: String) -> ValidationResult {
        if value.count <= maxLength {
            return .valid
        }
        return .invalid(message ?? "Must be at most \(maxLength) characters long")
    }
}

/// Validates string against a regular expression pattern.
public struct PatternRule: ValidationRule {
    public let pattern: String
    public let message: String
    
    public init(pattern: String, message: String) {
        self.pattern = pattern
        self.message = message
    }
    
    public func validate(_ value: String) -> ValidationResult {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: value.utf16.count)
        
        if regex?.firstMatch(in: value, options: [], range: range) != nil {
            return .valid
        }
        return .invalid(message)
    }
}

/// Validates email format.
public struct EmailRule: ValidationRule {
    public let message: String
    
    public init(message: String = "Invalid email format") {
        self.message = message
    }
    
    public func validate(_ value: String) -> ValidationResult {
        // Basic email regex pattern
        let emailPattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let rule = PatternRule(pattern: emailPattern, message: message)
        return rule.validate(value)
    }
}

/// Validates numeric range.
public struct RangeRule<T: Comparable>: ValidationRule {
    public let range: ClosedRange<T>
    public let message: String?
    
    public init(_ range: ClosedRange<T>, message: String? = nil) {
        self.range = range
        self.message = message
    }
    
    public func validate(_ value: T) -> ValidationResult {
        if range.contains(value) {
            return .valid
        }
        return .invalid(message ?? "Value must be between \(range.lowerBound) and \(range.upperBound)")
    }
}

/// Validates minimum value.
public struct MinRule<T: Comparable>: ValidationRule {
    public let minimum: T
    public let message: String?
    
    public init(_ minimum: T, message: String? = nil) {
        self.minimum = minimum
        self.message = message
    }
    
    public func validate(_ value: T) -> ValidationResult {
        if value >= minimum {
            return .valid
        }
        return .invalid(message ?? "Value must be at least \(minimum)")
    }
}

/// Validates maximum value.
public struct MaxRule<T: Comparable>: ValidationRule {
    public let maximum: T
    public let message: String?
    
    public init(_ maximum: T, message: String? = nil) {
        self.maximum = maximum
        self.message = message
    }
    
    public func validate(_ value: T) -> ValidationResult {
        if value <= maximum {
            return .valid
        }
        return .invalid(message ?? "Value must be at most \(maximum)")
    }
}

// MARK: - Composite Rules

/// Combines multiple validation rules with AND logic.
public struct AndRule<Value>: ValidationRule {
    private let rules: [any ValidationRule<Value>]
    
    public init(_ rules: any ValidationRule<Value>...) {
        self.rules = rules
    }
    
    public init(rules: [any ValidationRule<Value>]) {
        self.rules = rules
    }
    
    public func validate(_ value: Value) -> ValidationResult {
        for rule in rules {
            let result = rule.validate(value)
            if !result.isValid {
                return result
            }
        }
        return .valid
    }
}

/// Combines multiple validation rules with OR logic.
public struct OrRule<Value>: ValidationRule {
    private let rules: [any ValidationRule<Value>]
    private let message: String
    
    public init(_ rules: any ValidationRule<Value>..., message: String = "None of the validation rules passed") {
        self.rules = rules
        self.message = message
    }
    
    public init(rules: [any ValidationRule<Value>], message: String = "None of the validation rules passed") {
        self.rules = rules
        self.message = message
    }
    
    public func validate(_ value: Value) -> ValidationResult {
        var errors: [String] = []
        
        for rule in rules {
            let result = rule.validate(value)
            if result.isValid {
                return .valid
            }
            if let error = result.errorMessage {
                errors.append(error)
            }
        }
        
        return .invalid(errors.isEmpty ? message : errors.joined(separator: " OR "))
    }
}

/// Negates a validation rule.
public struct NotRule<Value>: ValidationRule {
    private let rule: any ValidationRule<Value>
    private let message: String
    
    public init(_ rule: any ValidationRule<Value>, message: String) {
        self.rule = rule
        self.message = message
    }
    
    public func validate(_ value: Value) -> ValidationResult {
        let result = rule.validate(value)
        if result.isValid {
            return .invalid(message)
        }
        return .valid
    }
}

// MARK: - Custom Rule Builder

/// Creates a custom validation rule from a closure.
public struct CustomRule<Value>: ValidationRule {
    private let validation: (Value) -> ValidationResult
    
    public init(_ validation: @escaping (Value) -> ValidationResult) {
        self.validation = validation
    }
    
    public init(_ validation: @escaping (Value) -> Bool, message: String) {
        self.validation = { value in
            validation(value) ? .valid : .invalid(message)
        }
    }
    
    public func validate(_ value: Value) -> ValidationResult {
        validation(value)
    }
}

// MARK: - Optional Value Rules

/// Validates optional values, treating nil as valid.
public struct OptionalRule<T, Rule: ValidationRule>: ValidationRule where Rule.Value == T {
    public typealias Value = T?
    
    private let rule: Rule
    
    public init(_ rule: Rule) {
        self.rule = rule
    }
    
    public func validate(_ value: T?) -> ValidationResult {
        guard let value = value else {
            return .valid  // nil is considered valid for optional
        }
        return rule.validate(value)
    }
}

/// Validates that an optional value is not nil.
public struct RequiredRule<T>: ValidationRule {
    public typealias Value = T?
    
    private let message: String
    
    public init(message: String = "Value is required") {
        self.message = message
    }
    
    public func validate(_ value: T?) -> ValidationResult {
        if value != nil {
            return .valid
        }
        return .invalid(message)
    }
}
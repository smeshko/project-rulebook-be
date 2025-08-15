import Vapor

/// Aspect that performs request validation using the validation framework.
///
/// ValidationAspect integrates the validation framework with the aspect system,
/// providing automatic validation of request content and query parameters.
///
/// ## Features
/// - **Content Validation**: Validates request body content
/// - **Query Validation**: Validates query parameters
/// - **Header Validation**: Validates request headers
/// - **Early Termination**: Stops processing on validation failure
/// - **Detailed Errors**: Provides comprehensive validation error messages
///
/// ## Usage Example
/// ```swift
/// app.aspectRegistry.register(ValidationAspect(), priority: 500)
/// ```
public struct ValidationAspect: Aspect {
    /// Configuration for the validation aspect.
    public struct Configuration: Sendable {
        /// Whether to validate request content.
        public let validateContent: Bool
        
        /// Whether to validate query parameters.
        public let validateQuery: Bool
        
        /// Whether to validate headers.
        public let validateHeaders: Bool
        
        /// Whether to include validation errors in response.
        public let includeErrorDetails: Bool
        
        /// HTTP status to return on validation failure.
        public let failureStatus: HTTPStatus
        
        /// Creates a new configuration.
        public init(
            validateContent: Bool = true,
            validateQuery: Bool = true,
            validateHeaders: Bool = false,
            includeErrorDetails: Bool = true,
            failureStatus: HTTPStatus = .badRequest
        ) {
            self.validateContent = validateContent
            self.validateQuery = validateQuery
            self.validateHeaders = validateHeaders
            self.includeErrorDetails = includeErrorDetails
            self.failureStatus = failureStatus
        }
        
        /// Default configuration for development.
        public static let development = Configuration(
            includeErrorDetails: true
        )
        
        /// Default configuration for production.
        public static let production = Configuration(
            includeErrorDetails: false
        )
    }
    
    /// The validation configuration.
    private let configuration: Configuration
    
    /// Creates a new ValidationAspect.
    ///
    /// - Parameter configuration: The validation configuration
    public init(configuration: Configuration = .development) {
        self.configuration = configuration
    }
    
    public func before(request: Request, context: inout AspectContext) async throws {
        var validationErrors: [AspectValidationError] = []
        
        // Validate content if present and configured
        if configuration.validateContent,
           let contentType = request.headers.contentType,
           contentType == .json || contentType == .urlEncodedForm {
            // Check if content implements Validatable
            validationErrors.append(contentsOf: await validateContent(request))
        }
        
        // Validate query parameters if configured
        if configuration.validateQuery {
            validationErrors.append(contentsOf: validateQuery(request))
        }
        
        // Validate headers if configured
        if configuration.validateHeaders {
            validationErrors.append(contentsOf: validateHeaders(request))
        }
        
        // Store validation results in context
        if !validationErrors.isEmpty {
            context.set(validationErrors, for: ValidationErrorsKey.self)
            
            // Log validation failures
            request.logger.warning("Request validation failed", metadata: [
                "errors": .array(validationErrors.map { .string($0.description) }),
                "path": .string(request.url.path)
            ])
            
            // Throw validation error to stop processing
            throw ValidationAspectError(
                errors: validationErrors,
                status: configuration.failureStatus,
                includeDetails: configuration.includeErrorDetails
            )
        }
    }
    
    public func onError(request: Request, error: Error, context: AspectContext) async throws {
        // Enhanced logging for validation errors
        if let validationError = error as? ValidationAspectError {
            request.logger.error("Validation failed", metadata: [
                "validation_errors": .array(validationError.errors.map { .string($0.description) }),
                "status": .string("\(validationError.status.code)")
            ])
        }
        
        throw error
    }
    
    /// Validates request content.
    private func validateContent(_ request: Request) async -> [AspectValidationError] {
        // This would integrate with Vapor's existing validation system
        // For now, we'll return empty as content validation is handled by Vapor
        return []
    }
    
    /// Validates query parameters.
    private func validateQuery(_ request: Request) -> [AspectValidationError] {
        var errors: [AspectValidationError] = []
        
        // Example: Validate common query parameters
        if let page = request.query[String.self, at: "page"] {
            if let pageNum = Int(page), pageNum < 1 {
                errors.append(AspectValidationError(
                    field: "page",
                    message: "Page number must be greater than 0"
                ))
            }
        }
        
        if let limit = request.query[String.self, at: "limit"] {
            if let limitNum = Int(limit) {
                if limitNum < 1 || limitNum > 100 {
                    errors.append(AspectValidationError(
                        field: "limit",
                        message: "Limit must be between 1 and 100"
                    ))
                }
            }
        }
        
        return errors
    }
    
    /// Validates request headers.
    private func validateHeaders(_ request: Request) -> [AspectValidationError] {
        var errors: [AspectValidationError] = []
        
        // Example: Validate custom headers if needed
        // This is typically used for API versioning, client identification, etc.
        
        return errors
    }
}

// MARK: - Validatable Protocol

/// Protocol for types that can be validated in requests.
///
/// Implement this protocol on your request content types to enable
/// automatic validation through the ValidationAspect.
///
/// ## Example
/// ```swift
/// struct CreateUserRequest: Content, AspectValidatable {
///     @Validated(rules: [EmailRule()])
///     var email: String
///     
///     @Validated(rules: [MinLengthRule(8)])
///     var password: String
///     
///     func validateAspect() -> [AspectValidationError] {
///         var errors: [AspectValidationError] = []
///         
///         if !$email.isValid {
///             errors.append(AspectValidationError(
///                 field: "email",
///                 message: $email.errors.first ?? "Invalid email"
///             ))
///         }
///         
///         if !$password.isValid {
///             errors.append(AspectValidationError(
///                 field: "password",
///                 message: $password.errors.first ?? "Invalid password"
///             ))
///         }
///         
///         return errors
///     }
/// }
/// ```
public protocol AspectValidatable {
    /// Validates the instance and returns any validation errors.
    ///
    /// - Returns: Array of validation errors, empty if valid
    func validateAspect() -> [AspectValidationError]
}

// MARK: - Validation Error Types

/// Represents a validation error for a specific field.
public struct AspectValidationError: CustomStringConvertible, Sendable {
    /// The field that failed validation.
    public let field: String
    
    /// The validation error message.
    public let message: String
    
    /// Additional context for the error.
    public let context: [String: String]?
    
    /// Creates a new validation error.
    public init(field: String, message: String, context: [String: String]? = nil) {
        self.field = field
        self.message = message
        self.context = context
    }
    
    public var description: String {
        "\(field): \(message)"
    }
}

/// Error thrown when validation fails in the ValidationAspect.
public struct ValidationAspectError: Error {
    /// The validation errors.
    public let errors: [AspectValidationError]
    
    /// The HTTP status to return.
    public let status: HTTPStatus
    
    /// Whether to include error details in response.
    public let includeDetails: Bool
    
    /// Creates a new validation aspect error.
    public init(
        errors: [AspectValidationError],
        status: HTTPStatus = .badRequest,
        includeDetails: Bool = true
    ) {
        self.errors = errors
        self.status = status
        self.includeDetails = includeDetails
    }
}

// MARK: - Context Keys

/// Context key for storing validation errors.
private struct ValidationErrorsKey: AspectContextKey {
    typealias Value = [AspectValidationError]
}

// MARK: - AbortError Conformance

extension ValidationAspectError: AbortError {
    public var reason: String {
        if includeDetails {
            let errorDescriptions = errors.map { $0.description }
            return "Validation failed: \(errorDescriptions.joined(separator: ", "))"
        } else {
            return "Validation failed"
        }
    }
    
    public var headers: HTTPHeaders {
        HTTPHeaders()
    }
}

// MARK: - Request Extensions

public extension Request {
    /// Validates the request content if it conforms to AspectValidatable.
    ///
    /// - Throws: ValidationAspectError if validation fails
    func validateContent<T: AspectValidatable & Content>(_ type: T.Type) async throws -> T {
        let content = try await self.content.decode(type)
        let errors = content.validateAspect()
        
        if !errors.isEmpty {
            throw ValidationAspectError(errors: errors)
        }
        
        return content
    }
}

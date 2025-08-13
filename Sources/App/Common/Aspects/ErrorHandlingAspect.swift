import Vapor
import Foundation

/// Aspect that provides unified error handling with structured logging.
///
/// ErrorHandlingAspect centralizes error handling logic, providing consistent
/// error responses, structured logging, and correlation with request IDs.
/// It integrates with the existing ErrorMiddleware while adding enhanced
/// logging and metrics collection.
///
/// ## Features
/// - **Structured Logging**: Rich error context with correlation IDs
/// - **Error Classification**: Categorizes errors for better monitoring
/// - **Response Formatting**: Consistent error response structure
/// - **Metrics Collection**: Tracks error rates and types
/// - **Development Mode**: Enhanced error details in non-production
///
/// ## Integration
/// This aspect works alongside the existing ErrorMiddleware, providing
/// additional logging and metrics without replacing core error handling.
///
/// ## Usage Example
/// ```swift
/// app.aspectRegistry.register(
///     ErrorHandlingAspect(environment: app.environment),
///     priority: 100  // Low priority to run last
/// )
/// ```
public struct ErrorHandlingAspect: Aspect {
    /// Configuration for error handling behavior.
    public struct Configuration: Sendable {
        /// Whether to include stack traces in logs.
        public let includeStackTrace: Bool
        
        /// Whether to include error details in responses.
        public let includeErrorDetails: Bool
        
        /// Whether to log request/response bodies on error.
        public let logRequestBody: Bool
        
        /// Maximum request body size to log (in bytes).
        public let maxBodyLogSize: Int
        
        /// Whether to collect error metrics.
        public let collectMetrics: Bool
        
        /// Creates a new configuration.
        public init(
            includeStackTrace: Bool = false,
            includeErrorDetails: Bool = false,
            logRequestBody: Bool = false,
            maxBodyLogSize: Int = 1024,
            collectMetrics: Bool = true
        ) {
            self.includeStackTrace = includeStackTrace
            self.includeErrorDetails = includeErrorDetails
            self.logRequestBody = logRequestBody
            self.maxBodyLogSize = maxBodyLogSize
            self.collectMetrics = collectMetrics
        }
        
        /// Configuration for development environment.
        public static let development = Configuration(
            includeStackTrace: true,
            includeErrorDetails: true,
            logRequestBody: true,
            maxBodyLogSize: 4096,
            collectMetrics: true
        )
        
        /// Configuration for production environment.
        public static let production = Configuration(
            includeStackTrace: false,
            includeErrorDetails: false,
            logRequestBody: false,
            maxBodyLogSize: 0,
            collectMetrics: true
        )
        
        /// Creates configuration based on environment.
        public static func forEnvironment(_ environment: Environment) -> Configuration {
            switch environment {
            case .production:
                return .production
            case .development:
                return .development
            default:
                // Testing or custom environments
                return Configuration(
                    includeStackTrace: true,
                    includeErrorDetails: true,
                    logRequestBody: false,
                    collectMetrics: false
                )
            }
        }
    }
    
    /// The error handling configuration.
    private let configuration: Configuration
    
    /// The application environment.
    private let environment: Environment
    
    /// Creates a new ErrorHandlingAspect.
    ///
    /// - Parameters:
    ///   - configuration: The error handling configuration
    ///   - environment: The application environment
    public init(
        configuration: Configuration? = nil,
        environment: Environment
    ) {
        self.configuration = configuration ?? Configuration.forEnvironment(environment)
        self.environment = environment
    }
    
    public func before(request: Request, context: inout AspectContext) async throws {
        // Store request start time for duration calculation
        context.set(Date(), for: RequestStartTimeKey.self)
        
        // Store request details for error logging if needed
        if configuration.logRequestBody {
            await storeRequestDetails(request: request, context: &context)
        }
    }
    
    public func onError(request: Request, error: Error, context: AspectContext) async throws {
        var mutableContext = context
        // Get correlation ID from context or request
        let correlationID = context.get(CorrelationIDKey.self) ?? request.id
        
        // Calculate request duration
        let duration: TimeInterval
        if let startTime = context.get(RequestStartTimeKey.self) {
            duration = Date().timeIntervalSince(startTime)
        } else {
            duration = 0
        }
        
        // Classify the error
        let errorInfo = classifyError(error)
        
        // Build structured log metadata
        var metadata: Logger.Metadata = [
            "correlation_id": .string(correlationID),
            "error_type": .string(errorInfo.type.rawValue),
            "error_category": .string(errorInfo.category.rawValue),
            "http_status": .string("\(errorInfo.status.code)"),
            "request_method": .string(request.method.rawValue),
            "request_path": .string(request.url.path),
            "request_duration_ms": .string("\(Int(duration * 1000))"),
            "environment": .string(environment.name)
        ]
        
        // Add query parameters if present
        if let query = request.url.query {
            metadata["request_query"] = .string(query)
        }
        
        // Add error identifier if available
        if let identifiableError = error as? IdentifiableError {
            metadata["error_identifier"] = .string(identifiableError.identifier)
        }
        
        // Add stack trace in development
        if configuration.includeStackTrace {
            metadata["stack_trace"] = .string(String(describing: error))
        }
        
        // Add request body if configured and stored
        if configuration.logRequestBody,
           let requestBody = context.get(RequestBodyKey.self) {
            metadata["request_body"] = .string(requestBody)
        }
        
        // Add user context if authenticated (commented out as Payload may not be available in all contexts)
        // TODO: Uncomment when Payload is available in the module
        // if let userPayload = request.auth.get(Payload.self) {
        //     metadata["user_id"] = .string(userPayload.id.uuidString)
        //     metadata["user_email"] = .string(userPayload.email)
        // }
        
        // Log the error with appropriate level
        logError(
            error: error,
            info: errorInfo,
            metadata: metadata,
            logger: request.logger
        )
        
        // Collect metrics if configured
        if configuration.collectMetrics {
            collectErrorMetrics(
                error: error,
                info: errorInfo,
                context: context,
                request: request
            )
        }
        
        // Store error info in context for response enhancement
        mutableContext.set(errorInfo, for: ErrorInfoKey.self)
        
        // Update request's aspect context with the modified one
        request.aspectContext = mutableContext
        
        // Rethrow the error for normal processing
        throw error
    }
    
    /// Stores request details for error logging.
    private func storeRequestDetails(request: Request, context: inout AspectContext) async {
        // Store request body if small enough
        if let body = request.body.data,
           body.readableBytes <= configuration.maxBodyLogSize {
            let bodyString = body.getString(at: 0, length: body.readableBytes) ?? ""
            context.set(bodyString, for: RequestBodyKey.self)
        }
    }
    
    /// Classifies an error for logging and metrics.
    private func classifyError(_ error: Error) -> ErrorInfo {
        let type: ErrorType
        let category: ErrorCategory
        let status: HTTPStatus
        
        // Determine error type and status
        switch error {
        case let appError as AppError:
            type = .application
            status = appError.status
            category = categorizeStatus(status)
            
        case let authError as AuthenticationError:
            type = .authentication
            status = authError.status
            category = .clientError
            
        case let validationError as ValidationAspectError:
            type = .validation
            status = validationError.status
            category = .clientError
            
        case let abortError as AbortError:
            type = .abort
            status = abortError.status
            category = categorizeStatus(status)
            
        case is DecodingError:
            type = .decoding
            status = .badRequest
            category = .clientError
            
        case is EncodingError:
            type = .encoding
            status = .internalServerError
            category = .serverError
            
        default:
            type = .unknown
            status = .internalServerError
            category = .serverError
        }
        
        return ErrorInfo(
            type: type,
            category: category,
            status: status,
            message: (error as? AbortError)?.reason ?? String(describing: error)
        )
    }
    
    /// Categorizes HTTP status code.
    private func categorizeStatus(_ status: HTTPStatus) -> ErrorCategory {
        switch status.code {
        case 400..<500:
            return .clientError
        case 500..<600:
            return .serverError
        default:
            return .unknown
        }
    }
    
    /// Logs error with appropriate level based on classification.
    private func logError(
        error: Error,
        info: ErrorInfo,
        metadata: Logger.Metadata,
        logger: Logger
    ) {
        let message = "Request failed: \(info.message)"
        
        switch info.category {
        case .clientError:
            // Client errors are warnings (expected failures)
            logger.warning(.init(stringLiteral: message), metadata: metadata)
            
        case .serverError:
            // Server errors are errors (unexpected failures)
            logger.error(.init(stringLiteral: message), metadata: metadata)
            
        case .unknown:
            // Unknown errors are also logged as errors
            logger.error(.init(stringLiteral: message), metadata: metadata)
        }
    }
    
    /// Collects error metrics for monitoring.
    private func collectErrorMetrics(
        error: Error,
        info: ErrorInfo,
        context: AspectContext,
        request: Request
    ) {
        // This would integrate with your metrics system
        // For now, we'll just log a metric event
        request.logger.info("Error metric", metadata: [
            "metric_type": .string("error"),
            "error_type": .string(info.type.rawValue),
            "error_category": .string(info.category.rawValue),
            "status_code": .string("\(info.status.code)"),
            "path": .string(request.url.path)
        ])
    }
}

// MARK: - Error Classification Types

/// Type of error for classification.
public enum ErrorType: String, Sendable {
    case application = "application"
    case authentication = "authentication"
    case validation = "validation"
    case abort = "abort"
    case decoding = "decoding"
    case encoding = "encoding"
    case database = "database"
    case network = "network"
    case unknown = "unknown"
}

/// Category of error for metrics.
public enum ErrorCategory: String, Sendable {
    case clientError = "client_error"
    case serverError = "server_error"
    case unknown = "unknown"
}

/// Information about a classified error.
public struct ErrorInfo: Sendable {
    public let type: ErrorType
    public let category: ErrorCategory
    public let status: HTTPStatus
    public let message: String
}

// MARK: - Context Keys

/// Context key for request start time.
private struct RequestStartTimeKey: AspectContextKey {
    typealias Value = Date
}

/// Context key for request body storage.
private struct RequestBodyKey: AspectContextKey {
    typealias Value = String
}

/// Context key for error information.
private struct ErrorInfoKey: AspectContextKey {
    typealias Value = ErrorInfo
}

/// Context key for correlation ID (shared with CorrelationIDAspect).
private struct CorrelationIDKey: AspectContextKey {
    typealias Value = String
}

// MARK: - Response Enhancement

public extension Response {
    /// Adds error tracking headers to the response.
    ///
    /// This can be called by error middleware to add tracking headers
    /// based on the error handling aspect's classification.
    func addErrorTrackingHeaders(from request: Request) {
        if let errorInfo = request.aspectContext.get(ErrorInfoKey.self) {
            headers.add(name: "X-Error-Type", value: errorInfo.type.rawValue)
            headers.add(name: "X-Error-Category", value: errorInfo.category.rawValue)
        }
        
        // Add correlation ID if available
        if let correlationID = request.aspectContext.get(CorrelationIDKey.self) {
            headers.replaceOrAdd(name: "X-Correlation-ID", value: correlationID)
        }
    }
}
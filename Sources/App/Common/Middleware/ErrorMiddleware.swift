import JWT
import Vapor
import Foundation

public struct ErrorResponse: Codable {
    public var error: Bool
    public var reason: String
    public var errorIdentifier: String?
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

public extension ErrorMiddleware {
    static func `custom`(environment: Environment) -> ErrorMiddleware {
        return .init { req, error in
            // Classify the error for structured logging and metrics
            let errorInfo = classifyError(error)
            
            let status = errorInfo.status
            let reason = errorInfo.message
            var headers = HTTPHeaders()
            let errorIdentifier: String?
            
            // Extract headers and identifier from specific error types
            switch error {
            case let appError as AppError:
                headers = appError.headers
                errorIdentifier = appError.identifier
            case let jwt as JWTError:
                headers = jwt.headers
                errorIdentifier = nil
            case let abort as AbortError:
                headers = abort.headers
                errorIdentifier = nil
            default:
                errorIdentifier = nil
            }
            
            // Get correlation ID for structured logging
            let correlationID = req.correlationID
            
            // Build structured log metadata
            var metadata: Logger.Metadata = [
                "correlation_id": .string(correlationID),
                "error_type": .string(errorInfo.type.rawValue),
                "error_category": .string(errorInfo.category.rawValue),
                "http_status": .string("\(status.code)"),
                "request_method": .string(req.method.rawValue),
                "request_path": .string(req.url.path),
                "environment": .string(environment.name)
            ]
            
            // Add query parameters if present
            if let query = req.url.query {
                metadata["request_query"] = .string(query)
            }
            
            // Add error identifier if available
            if let identifiableError = error as? IdentifiableError {
                metadata["error_identifier"] = .string(identifiableError.identifier)
            }
            
            // Add stack trace in development
            if !environment.isRelease {
                metadata["stack_trace"] = .string(String(describing: error))
            }
            
            // Log the error with appropriate level based on classification
            logError(
                error: error,
                info: errorInfo,
                metadata: metadata,
                logger: req.logger
            )
            
            // Create response with appropriate status
            let response = Response(status: status, headers: headers)
            
            // Add correlation ID to response headers
            response.headers.replaceOrAdd(name: "X-Correlation-ID", value: correlationID)
            
            // Add error tracking headers
            response.headers.add(name: "X-Error-Type", value: errorInfo.type.rawValue)
            response.headers.add(name: "X-Error-Category", value: errorInfo.category.rawValue)
            
            // Attempt to serialize the error to JSON
            do {
                let errorResponse = ErrorResponse(
                    error: true,
                    reason: reason,
                    errorIdentifier: errorIdentifier
                )
                response.body = try .init(data: JSONEncoder().encode(errorResponse))
                response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
            } catch {
                response.body = .init(string: "Oops: \(error)")
                response.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
            }
            
            return response
        }
    }
    
    /// Classifies an error for logging and metrics.
    private static func classifyError(_ error: Error) -> ErrorInfo {
        let type: ErrorType
        let category: ErrorCategory
        let status: HTTPStatus
        let message: String
        
        // Determine error type and status
        switch error {
        case let appError as AppError:
            type = .application
            status = appError.status
            category = categorizeStatus(status)
            message = appError.reason
            
        case let authError as AuthenticationError:
            type = .authentication
            status = authError.status
            category = .clientError
            message = authError.reason
            
        case let abortError as AbortError:
            type = .abort
            status = abortError.status
            category = categorizeStatus(status)
            message = abortError.reason
            
        case is DecodingError:
            type = .decoding
            status = .badRequest
            category = .clientError
            message = "Invalid request format"
            
        case is EncodingError:
            type = .encoding
            status = .internalServerError
            category = .serverError
            message = "Response encoding failed"
            
        case let localizedError as LocalizedError:
            type = .unknown
            status = .internalServerError
            category = .serverError
            message = localizedError.localizedDescription
            
        default:
            type = .unknown
            status = .internalServerError
            category = .serverError
            message = "Something went wrong."
        }
        
        return ErrorInfo(
            type: type,
            category: category,
            status: status,
            message: message
        )
    }
    
    /// Categorizes HTTP status code.
    private static func categorizeStatus(_ status: HTTPStatus) -> ErrorCategory {
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
    private static func logError(
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
}

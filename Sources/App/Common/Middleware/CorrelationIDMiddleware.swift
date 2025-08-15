import Vapor
import Foundation

/// Native Vapor middleware that manages correlation IDs for request tracing.
///
/// CorrelationIDMiddleware ensures every request has a unique correlation ID
/// for distributed tracing and log correlation. It propagates existing IDs
/// from incoming requests or generates new ones as needed.
///
/// ## Features
/// - **ID Propagation**: Preserves correlation IDs from upstream services
/// - **ID Generation**: Creates new IDs for requests without them
/// - **Header Management**: Adds correlation ID to response headers
/// - **Logger Metadata**: Enriches logs with correlation information
/// - **Request Storage**: Stores correlation ID in Vapor's request storage
///
/// ## Headers
/// - Incoming: `X-Correlation-ID`, `X-Request-ID`, `X-Trace-ID`
/// - Outgoing: `X-Correlation-ID`
///
/// ## Usage Example
/// ```swift
/// app.middleware.use(CorrelationIDMiddleware())
/// ```
public struct CorrelationIDMiddleware: AsyncMiddleware {
    /// Header names to check for existing correlation IDs.
    private let incomingHeaders = [
        "X-Correlation-ID",
        "X-Request-ID", 
        "X-Trace-ID",
        "X-B3-TraceId"  // Support for Zipkin B3 propagation
    ]
    
    /// Header name for outgoing correlation ID.
    private let outgoingHeader = "X-Correlation-ID"
    
    /// Creates a new CorrelationIDMiddleware.
    public init() {}
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Try to extract existing correlation ID from headers
        let correlationID = extractCorrelationID(from: request) ?? generateCorrelationID(from: request)
        
        // Store in request storage for access throughout the request lifecycle
        request.storage[CorrelationIDKey.self] = correlationID
        
        // Add to logger metadata for structured logging
        request.logger[metadataKey: "correlation_id"] = .string(correlationID)
        
        // Log request start with correlation ID
        request.logger.info("Request started", metadata: [
            "method": .string(request.method.rawValue),
            "path": .string(request.url.path),
            "correlation_id": .string(correlationID),
            "has_existing_id": .string(extractCorrelationID(from: request) != nil ? "true" : "false")
        ])
        
        do {
            // Process the request through the middleware chain
            let response = try await next.respond(to: request)
            
            // Add correlation ID to response headers
            response.headers.replaceOrAdd(name: outgoingHeader, value: correlationID)
            
            // Log request completion
            request.logger.info("Request completed", metadata: [
                "status": .string("\(response.status.code)"),
                "correlation_id": .string(correlationID)
            ])
            
            return response
            
        } catch {
            // Log error with correlation ID
            request.logger.error("Request failed", metadata: [
                "error": .string(String(describing: error)),
                "correlation_id": .string(correlationID),
                "error_type": .string(String(describing: type(of: error)))
            ])
            
            throw error
        }
    }
    
    /// Extracts correlation ID from request headers.
    ///
    /// Checks multiple header names for compatibility with different
    /// tracing systems and returns the first found value.
    ///
    /// - Parameter request: The incoming request
    /// - Returns: The extracted correlation ID, or nil if not found
    private func extractCorrelationID(from request: Request) -> String? {
        for headerName in incomingHeaders {
            if let value = request.headers[headerName].first,
               !value.isEmpty {
                return value
            }
        }
        return nil
    }
    
    /// Generates a new correlation ID using the application's UUID generator service.
    ///
    /// Falls back to system UUID generation if the service is not available.
    ///
    /// - Parameter request: The request to get the UUID generator from
    /// - Returns: A new correlation ID string
    private func generateCorrelationID(from request: Request) -> String {
        // Use the application's UUID generator service for consistency
        let uuidGenerator = request.services.uuidGenerator
        return uuidGenerator.generate().uuidString
    }
}

// MARK: - Storage Key

/// Storage key for storing correlation ID in request storage.
private struct CorrelationIDKey: StorageKey {
    typealias Value = String
}

// MARK: - Request Extensions

public extension Request {
    /// Gets the current correlation ID for this request.
    ///
    /// Returns the correlation ID set by the CorrelationIDMiddleware,
    /// or falls back to the request ID if not available.
    var correlationID: String {
        storage[CorrelationIDKey.self] ?? id
    }
}
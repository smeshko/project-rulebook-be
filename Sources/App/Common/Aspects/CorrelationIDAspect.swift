import Vapor
import Foundation

/// Aspect that manages correlation IDs for request tracing.
///
/// CorrelationIDAspect ensures every request has a unique correlation ID
/// for distributed tracing and log correlation. It propagates existing IDs
/// from incoming requests or generates new ones as needed.
///
/// ## Features
/// - **ID Propagation**: Preserves correlation IDs from upstream services
/// - **ID Generation**: Creates new IDs for requests without them
/// - **Header Management**: Adds correlation ID to response headers
/// - **Logger Metadata**: Enriches logs with correlation information
/// - **Request Context**: Updates RequestContext with correlation ID
///
/// ## Headers
/// - Incoming: `X-Correlation-ID`, `X-Request-ID`, `X-Trace-ID`
/// - Outgoing: `X-Correlation-ID`
///
/// ## Usage Example
/// ```swift
/// app.aspectRegistry.register(CorrelationIDAspect(), priority: 1000)
/// ```
public struct CorrelationIDAspect: Aspect {
    /// Header names to check for existing correlation IDs.
    private let incomingHeaders = [
        "X-Correlation-ID",
        "X-Request-ID",
        "X-Trace-ID",
        "X-B3-TraceId"  // Support for Zipkin B3 propagation
    ]
    
    /// Header name for outgoing correlation ID.
    private let outgoingHeader = "X-Correlation-ID"
    
    /// Service for generating UUIDs.
    private let uuidGenerator: (any UUIDGeneratorService)?
    
    /// Creates a new CorrelationIDAspect.
    ///
    /// - Parameter uuidGenerator: Optional UUID generator service.
    ///   If nil, uses system UUID generation.
    public init(uuidGenerator: (any UUIDGeneratorService)? = nil) {
        self.uuidGenerator = uuidGenerator
    }
    
    public func before(request: Request, context: inout AspectContext) async throws {
        // Try to extract existing correlation ID from headers
        let correlationID = extractCorrelationID(from: request) ?? generateCorrelationID()
        
        // Store in aspect context for later use
        context.set(correlationID, for: CorrelationIDKey.self)
        
        // Add to logger metadata
        request.logger[metadataKey: "correlation_id"] = .string(correlationID)
        
        // Note: request.id is immutable in Vapor, so we can't update it directly
        // The correlation ID is stored in the context and logger metadata instead
        
        // Log the request with correlation ID
        request.logger.info("Request started", metadata: [
            "method": .string(request.method.rawValue),
            "path": .string(request.url.path),
            "correlation_id": .string(correlationID),
            "has_existing_id": .string(extractCorrelationID(from: request) != nil ? "true" : "false")
        ])
    }
    
    public func after(request: Request, response: Response, context: AspectContext) async throws -> Response {
        // Add correlation ID to response headers
        if let correlationID = context.get(CorrelationIDKey.self) {
            response.headers.replaceOrAdd(name: outgoingHeader, value: correlationID)
            
            // Log the response with correlation ID
            request.logger.info("Request completed", metadata: [
                "status": .string("\(response.status.code)"),
                "correlation_id": .string(correlationID)
            ])
        }
        
        return response
    }
    
    public func onError(request: Request, error: Error, context: AspectContext) async throws {
        // Log error with correlation ID
        if let correlationID = context.get(CorrelationIDKey.self) {
            request.logger.error("Request failed", metadata: [
                "error": .string(String(describing: error)),
                "correlation_id": .string(correlationID),
                "error_type": .string(String(describing: type(of: error)))
            ])
        }
        
        throw error
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
    
    /// Generates a new correlation ID.
    ///
    /// Uses the configured UUID generator if available,
    /// otherwise falls back to system UUID generation.
    ///
    /// - Returns: A new correlation ID string
    private func generateCorrelationID() -> String {
        if let generator = uuidGenerator {
            return generator.generate().uuidString
        } else {
            return UUID().uuidString
        }
    }
}

// MARK: - Context Key

/// Context key for storing correlation ID.
private struct CorrelationIDKey: AspectContextKey {
    typealias Value = String
}

// MARK: - Middleware Wrapper

/// Legacy middleware wrapper for CorrelationIDAspect.
///
/// Provides backward compatibility for applications using traditional
/// middleware configuration instead of the aspect system.
///
/// ## Usage
/// ```swift
/// app.middleware.use(CorrelationIDMiddleware())
/// ```
public struct CorrelationIDMiddleware: AsyncMiddleware {
    /// The underlying correlation ID aspect.
    private let aspect: CorrelationIDAspect
    
    /// Creates a new CorrelationIDMiddleware.
    ///
    /// - Parameter uuidGenerator: Optional UUID generator service
    public init(uuidGenerator: (any UUIDGeneratorService)? = nil) {
        self.aspect = CorrelationIDAspect(uuidGenerator: uuidGenerator)
    }
    
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        var context = AspectContext()
        
        // Apply before phase
        try await aspect.before(request: request, context: &context)
        
        do {
            // Execute next middleware
            let response = try await next.respond(to: request)
            
            // Apply after phase
            return try await aspect.after(
                request: request,
                response: response,
                context: context
            )
        } catch {
            // Apply error phase
            try await aspect.onError(
                request: request,
                error: error,
                context: context
            )
            throw error
        }
    }
}

// MARK: - Request Extensions

public extension Request {
    /// Gets the current correlation ID for this request.
    ///
    /// Returns the correlation ID from the aspect context if available,
    /// otherwise falls back to the request ID.
    var correlationID: String {
        aspectContext.get(CorrelationIDKey.self) ?? id
    }
}

// MARK: - RequestContext Enhancement

public extension RequestContext {
    /// Creates a RequestContext with proper correlation ID from a request.
    ///
    /// This enhanced factory method ensures the correlation ID is properly
    /// propagated from the aspect system to the RequestContext.
    ///
    /// - Parameter request: The Vapor request
    /// - Returns: A RequestContext with correlation ID
    static func fromWithCorrelation(_ request: Request) -> RequestContext {
        let clientIP = request.application.services.ipExtractor.service.extractClientIP(from: request)
        
        // Use correlation ID from aspect if available, otherwise request ID
        let correlationID = request.correlationID
        
        // Create logger with correlation metadata
        var logger = request.logger
        logger[metadataKey: "correlation_id"] = .string(correlationID)
        
        return RequestContext(
            clientIP: clientIP,
            logger: logger,
            timestamp: Date(),
            requestID: correlationID
        )
    }
}
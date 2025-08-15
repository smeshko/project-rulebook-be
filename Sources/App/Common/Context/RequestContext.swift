import Foundation
import Vapor

/// Context structure that provides necessary dependencies for use cases and domain services
/// without exposing the entire Vapor.Request object.
///
/// This structure maintains Clean Architecture principles by:
/// - Providing explicit dependencies instead of framework objects
/// - Enabling easy testing through clear interfaces
/// - Reducing coupling to the Vapor framework
/// - Making service requirements explicit and discoverable
public struct RequestContext: Sendable {
    
    /// Client IP address extracted from the request
    public let clientIP: String
    
    /// Logger instance for structured logging
    public let logger: Logger
    
    /// Timestamp when the request context was created
    public let timestamp: Date
    
    /// Request ID for tracing and correlation
    public let requestID: String
    
    public init(
        clientIP: String,
        logger: Logger,
        timestamp: Date = Date.now,
        requestID: String = UUID().uuidString
    ) {
        self.clientIP = clientIP
        self.logger = logger
        self.timestamp = timestamp
        self.requestID = requestID
    }
}

// MARK: - Convenience Extensions

public extension RequestContext {
    /// Creates a RequestContext from a Vapor.Request
    static func from(_ request: Request) -> RequestContext {
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        
        // Use correlation ID from CorrelationIDMiddleware if available, otherwise request ID
        let correlationID = request.correlationID
        
        // Create logger with correlation metadata
        var logger = request.logger
        logger[metadataKey: "correlation_id"] = .string(correlationID)
        
        return RequestContext(
            clientIP: clientIP,
            logger: logger,
            requestID: correlationID
        )
    }
}
import Vapor

/// Protocol defining cross-cutting concerns that can be applied to requests.
///
/// Aspects provide a way to implement cross-cutting concerns like logging, validation,
/// security, and monitoring in a modular and reusable way. They follow the Aspect-Oriented
/// Programming paradigm to separate concerns from business logic.
///
/// ## Key Features
/// - **Before Execution**: Pre-process requests before handlers
/// - **After Execution**: Post-process responses after handlers
/// - **Error Handling**: Unified error processing across the application
/// - **Context Enrichment**: Add metadata and context to requests
/// - **Performance Monitoring**: Track execution times and metrics
///
/// ## Implementation Example
/// ```swift
/// struct LoggingAspect: Aspect {
///     func before(request: Request, context: inout AspectContext) async throws {
///         context.startTime = Date()
///         request.logger.info("Request started", metadata: [
///             "method": .string(request.method.rawValue),
///             "path": .string(request.url.path)
///         ])
///     }
///     
///     func after(request: Request, response: Response, context: AspectContext) async throws {
///         let duration = Date().timeIntervalSince(context.startTime ?? Date())
///         request.logger.info("Request completed", metadata: [
///             "duration": .string("\(duration)s"),
///             "status": .string("\(response.status.code)")
///         ])
///     }
/// }
/// ```
public protocol Aspect: Sendable {
    /// Called before the request is processed by the handler.
    ///
    /// Use this method to:
    /// - Validate request preconditions
    /// - Add context or metadata to the request
    /// - Initialize tracking or monitoring
    /// - Transform request data
    ///
    /// - Parameters:
    ///   - request: The incoming request
    ///   - context: Mutable context for passing data between aspect phases
    /// - Throws: Errors that should abort request processing
    func before(request: Request, context: inout AspectContext) async throws
    
    /// Called after the request has been processed by the handler.
    ///
    /// Use this method to:
    /// - Add headers to the response
    /// - Log response information
    /// - Clean up resources
    /// - Collect metrics
    ///
    /// - Parameters:
    ///   - request: The original request
    ///   - response: The response from the handler
    ///   - context: Context containing data from the before phase
    /// - Returns: Potentially modified response
    func after(request: Request, response: Response, context: AspectContext) async throws -> Response
    
    /// Called when an error occurs during request processing.
    ///
    /// Use this method to:
    /// - Log errors with context
    /// - Transform error responses
    /// - Send error notifications
    /// - Track error metrics
    ///
    /// - Parameters:
    ///   - request: The original request
    ///   - error: The error that occurred
    ///   - context: Context containing data from previous phases
    /// - Throws: The error to be handled by the next aspect or error middleware
    func onError(request: Request, error: Error, context: AspectContext) async throws
}

// MARK: - Default Implementations

public extension Aspect {
    /// Default implementation that does nothing before request processing.
    func before(request: Request, context: inout AspectContext) async throws {
        // Default: no-op
    }
    
    /// Default implementation that returns the response unchanged.
    func after(request: Request, response: Response, context: AspectContext) async throws -> Response {
        return response
    }
    
    /// Default implementation that rethrows the error unchanged.
    func onError(request: Request, error: Error, context: AspectContext) async throws {
        throw error
    }
}

/// Context for passing data between aspect phases.
///
/// AspectContext provides a type-safe way to share data between the before, after,
/// and error phases of aspect execution. It uses a storage mechanism similar to
/// Vapor's Request.storage for maintaining state throughout the request lifecycle.
///
/// ## Usage Example
/// ```swift
/// struct TimingAspect: Aspect {
///     func before(request: Request, context: inout AspectContext) async throws {
///         context.set(Date(), for: TimingKey.self)
///     }
///     
///     func after(request: Request, response: Response, context: AspectContext) async throws -> Response {
///         if let startTime = context.get(TimingKey.self) {
///             let duration = Date().timeIntervalSince(startTime)
///             response.headers.add(name: "X-Response-Time", value: "\(duration)ms")
///         }
///         return response
///     }
/// }
///
/// private struct TimingKey: AspectContextKey {
///     typealias Value = Date
/// }
/// ```
public struct AspectContext: Sendable {
    /// Internal storage for context values.
    private var storage: [ObjectIdentifier: any Sendable] = [:]
    
    /// Creates a new empty aspect context.
    public init() {}
    
    /// Stores a value in the context for a specific key type.
    ///
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key type identifying the value
    public mutating func set<T: AspectContextKey>(_ value: T.Value, for key: T.Type) {
        storage[ObjectIdentifier(key)] = value
    }
    
    /// Retrieves a value from the context for a specific key type.
    ///
    /// - Parameter key: The key type identifying the value
    /// - Returns: The stored value, or nil if not present
    public func get<T: AspectContextKey>(_ key: T.Type) -> T.Value? {
        storage[ObjectIdentifier(key)] as? T.Value
    }
    
    /// Removes a value from the context for a specific key type.
    ///
    /// - Parameter key: The key type identifying the value to remove
    /// - Returns: The removed value, or nil if not present
    @discardableResult
    public mutating func remove<T: AspectContextKey>(_ key: T.Type) -> T.Value? {
        storage.removeValue(forKey: ObjectIdentifier(key)) as? T.Value
    }
    
    /// Checks if a value exists in the context for a specific key type.
    ///
    /// - Parameter key: The key type to check
    /// - Returns: True if a value exists for the key
    public func has<T: AspectContextKey>(_ key: T.Type) -> Bool {
        storage[ObjectIdentifier(key)] != nil
    }
}

/// Protocol for defining type-safe keys for AspectContext storage.
///
/// Implement this protocol to create strongly-typed keys for storing
/// values in AspectContext. This ensures type safety and prevents
/// key collisions.
///
/// ## Example
/// ```swift
/// struct RequestIDKey: AspectContextKey {
///     typealias Value = String
/// }
/// 
/// // Usage
/// context.set("req-123", for: RequestIDKey.self)
/// let requestID = context.get(RequestIDKey.self)
/// ```
public protocol AspectContextKey {
    /// The type of value associated with this key.
    associatedtype Value: Sendable
}
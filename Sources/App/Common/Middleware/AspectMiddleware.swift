import Vapor

/// Middleware that applies aspects to incoming requests.
///
/// AspectMiddleware provides a powerful way to apply cross-cutting concerns
/// to your Vapor application. It executes aspects in order, allowing each
/// aspect to process the request before and after the main handler.
///
/// ## Architecture
/// - **Composable**: Multiple aspects can be chained together
/// - **Ordered Execution**: Aspects execute in the order they're registered
/// - **Error Resilient**: Error handling flows through all aspects
/// - **Performance Optimized**: Minimal overhead for aspect execution
///
/// ## Execution Flow
/// 1. Before phase: Aspects execute in registration order
/// 2. Handler execution: Main request handler processes the request
/// 3. After phase: Aspects execute in reverse order
/// 4. Error phase: All aspects handle errors if they occur
///
/// ## Usage Example
/// ```swift
/// // In configure.swift
/// app.middleware.use(AspectMiddleware(aspects: [
///     CorrelationIDAspect(),
///     LoggingAspect(),
///     ValidationAspect(),
///     MetricsAspect()
/// ]))
/// ```
public struct AspectMiddleware: AsyncMiddleware {
    /// The aspects to apply to requests.
    private let aspects: [any Aspect]
    
    /// Creates a new AspectMiddleware with the specified aspects.
    ///
    /// - Parameter aspects: The aspects to apply, in execution order
    public init(aspects: [any Aspect]) {
        self.aspects = aspects
    }
    
    /// Processes the request through all configured aspects.
    ///
    /// This method orchestrates the execution of all aspects around the
    /// main request handler. It ensures proper error handling and context
    /// propagation throughout the aspect chain.
    ///
    /// ## Execution Details
    /// - Before phase runs aspects in forward order
    /// - After phase runs aspects in reverse order
    /// - Errors trigger the error phase for all aspects
    /// - Context is shared across all phases
    ///
    /// - Parameters:
    ///   - request: The incoming request
    ///   - next: The next responder in the middleware chain
    /// - Returns: The processed response
    public func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        var context = AspectContext()
        
        do {
            // Execute before phase for all aspects
            for aspect in aspects {
                try await aspect.before(request: request, context: &context)
            }
            
            // Store the context on the request for access by route handlers
            request.aspectContext = context
            
            // Execute the main handler
            var response = try await next.respond(to: request)
            
            // Execute after phase for all aspects in reverse order
            for aspect in aspects.reversed() {
                response = try await aspect.after(
                    request: request,
                    response: response,
                    context: context
                )
            }
            
            return response
            
        } catch {
            // Execute error phase for all aspects
            var currentError = error
            
            for aspect in aspects {
                do {
                    try await aspect.onError(
                        request: request,
                        error: currentError,
                        context: context
                    )
                } catch let transformedError {
                    // Update the error if the aspect transforms it
                    currentError = transformedError
                }
            }
            
            throw currentError
        }
    }
}

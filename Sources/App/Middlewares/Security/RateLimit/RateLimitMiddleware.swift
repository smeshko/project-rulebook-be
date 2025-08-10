import Vapor

/// Intelligent rate limiting middleware with operation-specific limits and comprehensive monitoring.
///
/// This middleware implements a sophisticated rate limiting system that applies different
/// limits based on the type and cost of operations, providing optimal protection while
/// maintaining good user experience for legitimate users.
///
/// ## Key Features
/// - **Operation-Specific Limits**: Different limits for AI, admin, API, and general operations
/// - **IP-Based Tracking**: Client identification using reliable IP extraction
/// - **Sliding Window**: Time-based windows with automatic cleanup of old entries
/// - **Comprehensive Headers**: Rate limit status information in HTTP responses
/// - **Detailed Logging**: Security event logging for monitoring and analysis
/// - **Graceful Degradation**: Clear error responses with retry timing information
///
/// ## Rate Limiting Strategy
///
/// Uses a **tiered approach** with four protection levels:
/// 1. **AI Operations** (Most Restrictive): 3-50 requests/hour depending on environment
/// 2. **Admin Operations** (Restricted): 10-200 requests/5 minutes
/// 3. **API Operations** (Moderate): 50-1000 requests/hour
/// 4. **General Operations** (Lenient): 500-10,000 requests/hour
///
/// ## Security Benefits
/// - **DoS Protection**: Prevents resource exhaustion through request flooding
/// - **Cost Control**: Limits expensive AI operations to prevent budget overruns
/// - **Admin Protection**: Restricts access to sensitive administrative endpoints
/// - **Fair Usage**: Ensures resources are available for all legitimate users
///
/// ## Implementation Details
/// - **Storage**: Uses ``RateLimitStorage`` for efficient request tracking
/// - **Cleanup**: Automatic cleanup of expired rate limit entries
/// - **Performance**: Optimized for high-throughput request processing
/// - **Thread Safety**: Concurrent request handling without data races
struct RateLimitMiddleware: AsyncMiddleware {
    /// Shared storage instance for tracking rate limit state across requests.
    ///
    /// Uses a singleton pattern to maintain consistent rate limiting state
    /// across all middleware instances and request processing threads.
    private let storage: RateLimitStorage
    
    /// Configuration defining rate limits for different operation types.
    ///
    /// Contains the specific limits, time windows, and thresholds used
    /// to determine when requests should be throttled or allowed.
    private let configuration: RateLimitConfiguration
    
    /// Initializes the rate limiting middleware with the specified configuration.
    ///
    /// Creates a new middleware instance that will apply the provided rate limiting
    /// rules to all requests passing through the middleware chain.
    ///
    /// - Parameter configuration: Rate limiting configuration with operation-specific limits
    init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
        self.storage = RateLimitStorage.shared
    }
    
    /// Processes requests through the rate limiting system with operation-specific controls.
    ///
    /// This method implements the core rate limiting logic:
    /// 1. **Client Identification**: Extracts client IP address for tracking
    /// 2. **Operation Classification**: Determines rate limit category based on request path
    /// 3. **Limit Checking**: Verifies current request count against allowed limits
    /// 4. **Request Recording**: Records successful requests for future limit calculations
    /// 5. **Header Injection**: Adds rate limit status headers to responses
    ///
    /// ## Rate Limit Logic
    /// - Uses sliding time windows for accurate rate limiting
    /// - Automatically cleans up expired entries for memory efficiency
    /// - Provides detailed error responses when limits are exceeded
    /// - Records comprehensive logging for security monitoring
    ///
    /// ## Response Headers Added
    /// - `X-RateLimit-Limit`: Maximum requests allowed in time window
    /// - `X-RateLimit-Remaining`: Number of requests remaining in current window
    /// - `X-RateLimit-Type`: Type of rate limit applied (ai, admin, api, general)
    /// - `X-RateLimit-Window`: Time window duration in seconds
    /// - `Retry-After`: Recommended retry delay when limit exceeded (only on 429 responses)
    ///
    /// - Parameters:
    ///   - request: The incoming HTTP request to process
    ///   - next: The next responder in the middleware chain
    /// - Returns: HTTP response with rate limit headers
    /// - Throws: Rate limiting errors are converted to HTTP 429 responses
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let currentTime = Date()
        
        // Determine rate limit based on request path
        let rateLimitInfo = determineRateLimit(for: request)
        let operationKey = "\(rateLimitInfo.type.rawValue)_\(clientIP)"
        
        // Clean up old entries
        let cutoffTime = currentTime.addingTimeInterval(-Double(rateLimitInfo.windowSeconds))
        await storage.cleanup(olderThan: cutoffTime)
        
        // Check current rate limit for this specific operation
        let currentCount = await storage.getCount(for: operationKey, since: cutoffTime)
        
        if currentCount >= rateLimitInfo.maxRequests {
            let response = Response(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: "\(rateLimitInfo.windowSeconds)")
            response.headers.add(name: "X-RateLimit-Limit", value: "\(rateLimitInfo.maxRequests)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "0")
            response.headers.add(name: "X-RateLimit-Type", value: rateLimitInfo.type.rawValue)
            
            // Enhanced logging for rate limit violations
            request.logger.warning("Rate limit exceeded", metadata: [
                "client_ip": .string(clientIP),
                "operation_type": .string(rateLimitInfo.type.rawValue),
                "current_count": .string("\(currentCount)"),
                "limit": .string("\(rateLimitInfo.maxRequests)"),
                "window_seconds": .string("\(rateLimitInfo.windowSeconds)"),
                "path": .string(request.url.path),
                "method": .string(request.method.rawValue)
            ])
            
            return response
        }
        
        // Record this request
        await storage.record(operationKey: operationKey, at: currentTime)
        
        // Continue to next middleware
        let response = try await next.respond(to: request)
        
        // Add rate limit headers
        let remaining = rateLimitInfo.maxRequests - currentCount - 1
        response.headers.add(name: "X-RateLimit-Limit", value: "\(rateLimitInfo.maxRequests)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(max(0, remaining))")
        response.headers.add(name: "X-RateLimit-Type", value: rateLimitInfo.type.rawValue)
        response.headers.add(name: "X-RateLimit-Window", value: "\(rateLimitInfo.windowSeconds)")
        
        return response
    }
    
    /// Determines the appropriate rate limit category and settings for a request.
    ///
    /// This method analyzes the request path to classify the operation type and
    /// apply the corresponding rate limiting rules. The classification uses a
    /// hierarchical approach with the most specific rules taking precedence.
    ///
    /// ## Classification Hierarchy
    /// 1. **AI Operations** (Highest Priority):
    ///    - `/api/rules-generation/game-box-analysis` → Image Analysis limits
    ///    - `/api/rules-generation/rules-summary` → Rules Generation limits
    ///
    /// 2. **Admin Operations**:
    ///    - `/api/admin/*` → Admin operation limits
    ///
    /// 3. **API Operations**:
    ///    - `/api/*` → General API limits (catch-all for API endpoints)
    ///
    /// 4. **General Operations** (Default):
    ///    - All other requests → General web request limits
    ///
    /// ## Rate Limit Selection Logic
    /// - Uses path prefix matching for efficient classification
    /// - Prioritizes specific AI endpoints over general API limits
    /// - Falls back to general limits for unclassified requests
    /// - Provides appropriate time windows for each operation type
    ///
    /// - Parameter request: The HTTP request to classify
    /// - Returns: Rate limit information including type, limits, and time window
    private func determineRateLimit(for request: Request) -> RateLimitInfo {
        let path = request.url.path
        
        // AI-specific endpoints
        if path.contains("/api/rules-generation/game-box-analysis") {
            return RateLimitInfo(
                type: .imageAnalysis,
                maxRequests: configuration.imageAnalysisLimit,
                windowSeconds: configuration.imageAnalysisWindow
            )
        }
        
        if path.contains("/api/rules-generation/rules-summary") {
            return RateLimitInfo(
                type: .rulesGeneration,
                maxRequests: configuration.rulesGenerationLimit,
                windowSeconds: configuration.rulesGenerationWindow
            )
        }
        
        // Admin endpoints
        if path.contains("/api/admin/") {
            return RateLimitInfo(
                type: .admin,
                maxRequests: configuration.adminLimit,
                windowSeconds: configuration.adminWindow
            )
        }
        
        // API endpoints
        if path.hasPrefix("/api/") {
            return RateLimitInfo(
                type: .api,
                maxRequests: configuration.apiLimit,
                windowSeconds: configuration.apiWindow
            )
        }
        
        // General web endpoints
        return RateLimitInfo(
            type: .general,
            maxRequests: configuration.generalLimit,
            windowSeconds: configuration.generalWindow
        )
    }
}
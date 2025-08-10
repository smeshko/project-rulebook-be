import Vapor

/// Rate limiting middleware with configurable operation types
struct RateLimitMiddleware: AsyncMiddleware {
    private let storage: RateLimitStorage
    private let configuration: RateLimitConfiguration
    
    init(configuration: RateLimitConfiguration) {
        self.configuration = configuration
        self.storage = RateLimitStorage.shared
    }
    
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
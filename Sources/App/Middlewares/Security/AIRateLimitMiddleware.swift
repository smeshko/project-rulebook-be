import Vapor

/// AI-specific rate limiting middleware with different limits for different AI operations
struct AIRateLimitMiddleware: AsyncMiddleware {
    private let storage: AIRateLimitStorage
    
    // Rate limit configurations for different AI operations
    enum AIOperationType {
        case imageAnalysis    // 5 requests per hour
        case rulesGeneration  // 10 requests per hour
        case general         // 20 requests per hour (fallback)
        
        var maxRequests: Int {
            switch self {
            case .imageAnalysis:
                return 5
            case .rulesGeneration:
                return 10
            case .general:
                return 20
            }
        }
        
        var windowHours: Int {
            return 1 // All AI operations use 1-hour window
        }
        
        var windowSeconds: Int {
            return windowHours * 3600
        }
    }
    
    private let operationType: AIOperationType
    
    init(operationType: AIOperationType) {
        self.operationType = operationType
        self.storage = AIRateLimitStorage.shared
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let currentTime = Date()
        let operationKey = "\(operationType)_\(clientIP)"
        
        // Clean up old entries
        let cutoffTime = currentTime.addingTimeInterval(-Double(operationType.windowSeconds))
        await storage.cleanup(olderThan: cutoffTime)
        
        // Check current rate limit for this specific AI operation
        let currentCount = await storage.getCount(for: operationKey, since: cutoffTime)
        
        if currentCount >= operationType.maxRequests {
            // Log rate limit exceeded
            request.logger.warning("AI rate limit exceeded", metadata: [
                "operation": .string("\(operationType)"),
                "client_ip": .string(clientIP),
                "current_count": .string("\(currentCount)"),
                "limit": .string("\(operationType.maxRequests)"),
                "window_hours": .string("\(operationType.windowHours)")
            ])
            
            let response = Response(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: "\(operationType.windowSeconds)")
            response.headers.add(name: "X-RateLimit-Limit", value: "\(operationType.maxRequests)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "0")
            response.headers.add(name: "X-RateLimit-Window", value: "\(operationType.windowHours)h")
            response.headers.add(name: "X-RateLimit-Type", value: "AI-\(operationType)")
            
            // Add JSON error response for API clients
            let errorResponse = AIRateLimitError(
                error: "rate_limit_exceeded",
                message: "AI \(operationType) rate limit exceeded",
                limit: operationType.maxRequests,
                windowHours: operationType.windowHours,
                retryAfter: operationType.windowSeconds
            )
            
            try response.content.encode(errorResponse)
            response.headers.add(name: "Content-Type", value: "application/json")
            
            return response
        }
        
        // Record this request
        await storage.record(operationKey: operationKey, at: currentTime)
        
        // Continue to next middleware
        let response = try await next.respond(to: request)
        
        // Add rate limit headers to successful responses
        let remaining = operationType.maxRequests - currentCount - 1
        response.headers.add(name: "X-RateLimit-Limit", value: "\(operationType.maxRequests)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(max(0, remaining))")
        response.headers.add(name: "X-RateLimit-Window", value: "\(operationType.windowHours)h")
        response.headers.add(name: "X-RateLimit-Type", value: "AI-\(operationType)")
        
        return response
    }
}

// MARK: - AI Rate Limit Storage

/// Thread-safe storage for AI-specific rate limiting with operation-based keys
actor AIRateLimitStorage {
    static let shared = AIRateLimitStorage()
    
    private var requests: [String: [Date]] = [:]
    
    private init() {}
    
    func record(operationKey: String, at time: Date) {
        if requests[operationKey] == nil {
            requests[operationKey] = []
        }
        requests[operationKey]?.append(time)
    }
    
    func getCount(for operationKey: String, since time: Date) -> Int {
        return requests[operationKey]?.filter { $0 >= time }.count ?? 0
    }
    
    func cleanup(olderThan time: Date) {
        for (operationKey, dates) in requests {
            requests[operationKey] = dates.filter { $0 >= time }
            if requests[operationKey]?.isEmpty == true {
                requests.removeValue(forKey: operationKey)
            }
        }
    }
    
    /// Get current statistics for monitoring purposes
    func getStatistics() -> [String: Int] {
        var stats: [String: Int] = [:]
        for (operationKey, dates) in requests {
            stats[operationKey] = dates.count
        }
        return stats
    }
}

// MARK: - AI Rate Limit Error Response

struct AIRateLimitError: Content {
    let error: String
    let message: String
    let limit: Int
    let windowHours: Int
    let retryAfter: Int
    
    enum CodingKeys: String, CodingKey {
        case error
        case message
        case limit
        case windowHours = "window_hours"
        case retryAfter = "retry_after_seconds"
    }
}
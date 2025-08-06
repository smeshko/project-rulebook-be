import Vapor

struct RateLimitMiddleware: AsyncMiddleware {
    private let maxRequests: Int
    private let windowMinutes: Int
    private let storage: RateLimitStorage
    
    init(maxRequests: Int, windowMinutes: Int) {
        self.maxRequests = maxRequests
        self.windowMinutes = windowMinutes
        self.storage = RateLimitStorage()
    }
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let clientIP = request.remoteAddress?.hostname ?? "unknown"
        let currentTime = Date()
        
        // Clean up old entries
        await storage.cleanup(olderThan: currentTime.addingTimeInterval(-Double(windowMinutes * 60)))
        
        // Check current rate limit
        let currentCount = await storage.getCount(for: clientIP, since: currentTime.addingTimeInterval(-Double(windowMinutes * 60)))
        
        if currentCount >= maxRequests {
            let response = Response(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: "\(windowMinutes * 60)")
            response.headers.add(name: "X-RateLimit-Limit", value: "\(maxRequests)")
            response.headers.add(name: "X-RateLimit-Remaining", value: "0")
            return response
        }
        
        // Record this request
        await storage.record(clientIP: clientIP, at: currentTime)
        
        // Continue to next middleware
        let response = try await next.respond(to: request)
        
        // Add rate limit headers
        let remaining = maxRequests - currentCount - 1
        response.headers.add(name: "X-RateLimit-Limit", value: "\(maxRequests)")
        response.headers.add(name: "X-RateLimit-Remaining", value: "\(max(0, remaining))")
        
        return response
    }
}

actor RateLimitStorage {
    private var requests: [String: [Date]] = [:]
    
    func record(clientIP: String, at time: Date) {
        if requests[clientIP] == nil {
            requests[clientIP] = []
        }
        requests[clientIP]?.append(time)
    }
    
    func getCount(for clientIP: String, since time: Date) -> Int {
        return requests[clientIP]?.filter { $0 >= time }.count ?? 0
    }
    
    func cleanup(olderThan time: Date) {
        for (clientIP, dates) in requests {
            requests[clientIP] = dates.filter { $0 >= time }
            if requests[clientIP]?.isEmpty == true {
                requests.removeValue(forKey: clientIP)
            }
        }
    }
}
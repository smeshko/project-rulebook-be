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
        let clientIP = extractClientIP(from: request)
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
    
    /// Extracts the real client IP address from the request, checking proxy headers first
    private func extractClientIP(from request: Request) -> String {
        // Check X-Forwarded-For header (may contain multiple IPs, client is first)
        if let forwardedFor = request.headers.first(name: "X-Forwarded-For") {
            let trimmed = forwardedFor.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // Take the first IP address (the original client)
                let firstIP = String(trimmed.split(separator: ",").first ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if isValidIPAddress(firstIP) {
                    return firstIP
                }
            }
        }
        
        // Check X-Real-IP header (single IP)
        if let realIP = request.headers.first(name: "X-Real-IP") {
            let trimmed = realIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidIPAddress(trimmed) {
                return trimmed
            }
        }
        
        // Check X-Client-IP header (alternative header used by some proxies)
        if let clientIP = request.headers.first(name: "X-Client-IP") {
            let trimmed = clientIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidIPAddress(trimmed) {
                return trimmed
            }
        }
        
        // Check CF-Connecting-IP header (Cloudflare specific)
        if let cfIP = request.headers.first(name: "CF-Connecting-IP") {
            let trimmed = cfIP.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && isValidIPAddress(trimmed) {
                return trimmed
            }
        }
        
        // Fallback to remote address
        return request.remoteAddress?.hostname ?? "unknown"
    }
    
    /// Validates if a string is a valid IP address (IPv4 or IPv6)
    private func isValidIPAddress(_ ip: String) -> Bool {
        // Basic validation to avoid obviously malformed IPs
        guard !ip.isEmpty, ip != "unknown", ip != "localhost" else { return false }
        
        // Check for IPv4 format (simple regex-like check)
        if ip.contains(".") {
            let components = ip.split(separator: ".")
            guard components.count == 4 else { return false }
            return components.allSatisfy { component in
                guard let num = Int(component), num >= 0, num <= 255 else { return false }
                return true
            }
        }
        
        // Check for IPv6 format (basic validation)
        if ip.contains(":") {
            // IPv6 addresses can be complex, so we do a basic check
            let components = ip.split(separator: ":")
            guard components.count >= 2, components.count <= 8 else { return false }
            return components.allSatisfy { component in
                // Each component should be hexadecimal (0-9, a-f, A-F)
                return component.allSatisfy { char in
                    char.isHexDigit
                }
            }
        }
        
        return false
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
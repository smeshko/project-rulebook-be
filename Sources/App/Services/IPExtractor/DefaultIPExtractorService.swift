import Vapor

extension Application.Service.Provider where ServiceType == IPExtractorService {
    static var `default`: Self {
        .init {
            $0.services.ipExtractor.use { DefaultIPExtractorService(app: $0) }
        }
    }
}

struct DefaultIPExtractorService: IPExtractorService {
    let app: Application
    
    func extractClientIP(from request: Request) -> String {
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
    
    func `for`(_ request: Request) -> IPExtractorService {
        Self(app: request.application)
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

private extension Character {
    /// Checks if the character is a valid hexadecimal digit
    var isHexDigit: Bool {
        return self.isASCII && (
            (self >= "0" && self <= "9") ||
            (self >= "a" && self <= "f") ||
            (self >= "A" && self <= "F")
        )
    }
}
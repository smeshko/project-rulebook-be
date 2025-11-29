import Vapor

struct SecurityHeadersMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)

        // HSTS - HTTP Strict Transport Security
        response.headers.add(name: "Strict-Transport-Security", value: "max-age=31536000; includeSubDomains")

        // X-Content-Type-Options - Prevent MIME type sniffing
        response.headers.add(name: "X-Content-Type-Options", value: "nosniff")

        // X-Frame-Options - Prevent clickjacking
        response.headers.add(name: "X-Frame-Options", value: "DENY")

        // X-XSS-Protection - Enable XSS filtering (legacy support)
        response.headers.add(name: "X-XSS-Protection", value: "1; mode=block")

        // Referrer-Policy - Control referrer information
        response.headers.add(name: "Referrer-Policy", value: "strict-origin-when-cross-origin")

        // Content Security Policy - Prevent code injection
        // Relaxed CSP for Swagger UI documentation endpoint
        let isSwaggerUI = request.url.path == "/docs" || request.url.path == "/swagger"
        let csp: String
        if isSwaggerUI {
            csp = [
                "default-src 'self'",
                "script-src 'self' 'unsafe-inline' https://unpkg.com",  // Allow Swagger UI CDN
                "style-src 'self' 'unsafe-inline' https://unpkg.com",   // Allow Swagger UI CSS
                "img-src 'self' data:",
                "font-src 'self' https://unpkg.com",
                "connect-src 'self'",
                "frame-ancestors 'none'",
                "form-action 'self'"
            ].joined(separator: "; ")
        } else {
            csp = [
                "default-src 'self'",
                "script-src 'self' 'unsafe-inline'",  // Allow inline scripts for SwiftHtml templates
                "style-src 'self' 'unsafe-inline'",   // Allow inline styles
                "img-src 'self' data:",               // Allow images from self and data URIs
                "font-src 'self'",
                "connect-src 'self'",
                "frame-ancestors 'none'",
                "form-action 'self'"
            ].joined(separator: "; ")
        }
        response.headers.add(name: "Content-Security-Policy", value: csp)
        
        // Permissions Policy - Control browser features
        let permissionsPolicy = [
            "accelerometer=()",
            "camera=()",
            "geolocation=()",
            "gyroscope=()",
            "magnetometer=()",
            "microphone=()",
            "payment=()",
            "usb=()"
        ].joined(separator: ", ")
        response.headers.add(name: "Permissions-Policy", value: permissionsPolicy)
        
        return response
    }
}
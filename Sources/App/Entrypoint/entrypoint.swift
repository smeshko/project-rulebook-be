import Vapor
import Dispatch
import Logging

/// This extension is temporary and can be removed once Vapor gets this support.
private extension Vapor.Application {
    static let baseExecutionQueue = DispatchQueue(label: "vapor.codes.entrypoint")
    
    func runFromAsyncMainEntrypoint() async throws {
        try await withCheckedThrowingContinuation { continuation in
            Vapor.Application.baseExecutionQueue.async { [self] in
                do {
                    try self.run()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

@main
struct Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()

        // Use structured JSON logging in production/staging for log aggregation,
        // keep default text format in development for readability
        if env.name == "production" || env.name == "staging" {
            let logLevel: Logger.Level = Environment.get("LOG_LEVEL")
                .flatMap { Logger.Level(rawValue: $0) } ?? .info
            LoggingSystem.bootstrap { label in
                StructuredLogHandler(label: label, logLevel: logLevel)
            }
        } else {
            try LoggingSystem.bootstrap(from: &env)
        }

        let app = try await Application.make(env)
        
        do {
            try configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try await app.asyncShutdown()
            throw error
        }
        
        try await app.asyncShutdown()
    }
}

import Fluent
import FluentSQL
import Vapor

/// Middleware to monitor database query performance and log slow queries
public final class QueryPerformanceMiddleware: AsyncMiddleware, @unchecked Sendable {
    public struct Configuration: Sendable {
        /// Threshold in seconds for logging slow queries
        let slowQueryThreshold: TimeInterval
        /// Maximum number of query samples to log per request
        let maxSamplesPerRequest: Int
        
        public init(
            slowQueryThreshold: TimeInterval = 0.1,
            maxSamplesPerRequest: Int = 5
        ) {
            self.slowQueryThreshold = slowQueryThreshold
            self.maxSamplesPerRequest = maxSamplesPerRequest
        }
        
        public static let development = Configuration(
            slowQueryThreshold: 0.05, // 50ms
            maxSamplesPerRequest: 10
        )
        
        public static let production = Configuration(
            slowQueryThreshold: 0.1, // 100ms
            maxSamplesPerRequest: 3
        )
    }
    
    private let configuration: Configuration
    
    public init(configuration: Configuration = .production) {
        self.configuration = configuration
    }
    
    public func respond(to request: Request, chainingTo responder: AsyncResponder) async throws -> Response {
        let startTime = Date()
        
        // Log query performance for this request
        let originalLogger = request.logger
        let performanceLogger = QueryPerformanceLogger(
            originalLogger: originalLogger,
            configuration: configuration
        )
        
        // Store performance logger in request for repositories to use
        request.storage[QueryPerformanceLoggerKey.self] = performanceLogger
        
        let response: Response
        do {
            response = try await responder.respond(to: request)
        } catch {
            throw error
        }
        
        // Log request timing
        let requestDuration = Date().timeIntervalSince(startTime)
        let stats = performanceLogger.getStatistics()
        
        if stats.totalQueries > 0 {
            originalLogger.info("Request completed", metadata: [
                "duration_ms": .string(String(format: "%.2f", requestDuration * 1000)),
                "queries_count": .string("\(stats.totalQueries)"),
                "queries_duration_ms": .string(String(format: "%.2f", stats.totalDuration * 1000)),
                "slow_queries_count": .string("\(stats.slowQueryCount)")
            ])
        }
        
        return response
    }
}

/// Storage key for query performance logger
struct QueryPerformanceLoggerKey: StorageKey {
    typealias Value = QueryPerformanceLogger
}

/// Simple query performance logger
public final class QueryPerformanceLogger: Sendable {
    private let originalLogger: Logger
    private let configuration: QueryPerformanceMiddleware.Configuration
    private let statistics: QueryStatistics
    
    init(
        originalLogger: Logger,
        configuration: QueryPerformanceMiddleware.Configuration
    ) {
        self.originalLogger = originalLogger
        self.configuration = configuration
        self.statistics = QueryStatistics()
    }
    
    func logQuery(operation: String, duration: TimeInterval) {
        statistics.recordQuery(duration: duration)
        
        if duration > configuration.slowQueryThreshold {
            statistics.recordSlowQuery()
            originalLogger.warning("Slow query detected", metadata: [
                "operation": .string(operation),
                "duration_ms": .string(String(format: "%.2f", duration * 1000)),
                "threshold_ms": .string(String(format: "%.2f", configuration.slowQueryThreshold * 1000))
            ])
        }
    }
    
    func getStatistics() -> (totalQueries: Int, totalDuration: TimeInterval, slowQueryCount: Int) {
        return (
            totalQueries: statistics.totalQueries,
            totalDuration: statistics.totalDuration,
            slowQueryCount: statistics.slowQueryCount
        )
    }
}

/// Thread-safe statistics collector for query performance monitoring
private final class QueryStatistics: @unchecked Sendable {
    private var _totalQueries = 0
    private var _totalDuration: TimeInterval = 0
    private var _slowQueryCount = 0
    private let lock = NSLock()
    
    var totalQueries: Int {
        lock.lock()
        defer { lock.unlock() }
        return _totalQueries
    }
    
    var totalDuration: TimeInterval {
        lock.lock()
        defer { lock.unlock() }
        return _totalDuration
    }
    
    var slowQueryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _slowQueryCount
    }
    
    func recordQuery(duration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        _totalQueries += 1
        _totalDuration += duration
    }
    
    func recordSlowQuery() {
        lock.lock()
        defer { lock.unlock() }
        _slowQueryCount += 1
    }
}

/// Extension to add query performance logging to repositories
extension Request {
    var queryPerformanceLogger: QueryPerformanceLogger? {
        return storage[QueryPerformanceLoggerKey.self]
    }
}
@testable import App
import XCTest
import Vapor

/// Base test case for performance and benchmarking tests.
/// 
/// This class provides functionality for measuring performance of services,
/// endpoints, and business logic. Use this for tests that need to verify
/// performance characteristics and identify bottlenecks.
final class PerformanceTestCase {
    private let app: Application
    
    /// Initializes a new performance test case.
    ///
    /// - Throws: Configuration or setup errors
    init() async throws {
        self.app = try TestWorld.makeTestAppSync()
        // Performance configuration is now handled by TestWorld with ServiceRegistry
        // No additional setup needed
    }
    
    /// Cleans up resources when the test case is deallocated.
    deinit {
        // Note: Using sync shutdown in deinit since async is not supported
        // For proper async shutdown, use the shutdown() method explicitly
        app.shutdown()
    }
    
    /// Properly shuts down the application with async support.
    /// Should be called from test tearDown methods.
    func shutdown() async throws {
        try await app.asyncShutdown()
    }
    
    /// Access to the application instance.
    var application: Application {
        app
    }
    
    /// Measures the execution time of a given operation.
    ///
    /// - Parameters:
    ///   - name: Description of the operation being measured
    ///   - iterations: Number of times to run the operation (default: 100)
    ///   - operation: The async operation to measure
    /// - Returns: Performance metrics
    /// - Throws: Any errors from the operation
    func measure(
        _ name: String,
        iterations: Int = 100,
        operation: () async throws -> Void
    ) async rethrows -> PerformanceMetrics {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let startTime = Date()
            try await operation()
            let endTime = Date()
            times.append(endTime.timeIntervalSince(startTime))
        }
        
        return PerformanceMetrics(
            name: name,
            iterations: iterations,
            times: times
        )
    }
    
    /// Measures the execution time of a synchronous operation.
    ///
    /// - Parameters:
    ///   - name: Description of the operation being measured
    ///   - iterations: Number of times to run the operation (default: 100)
    ///   - operation: The synchronous operation to measure
    /// - Returns: Performance metrics
    /// - Throws: Any errors from the operation
    func measureSync<T>(
        _ name: String,
        iterations: Int = 100,
        operation: () throws -> T
    ) rethrows -> PerformanceMetrics {
        var times: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let startTime = Date()
            _ = try operation()
            let endTime = Date()
            times.append(endTime.timeIntervalSince(startTime))
        }
        
        return PerformanceMetrics(
            name: name,
            iterations: iterations,
            times: times
        )
    }
    
}

/// Performance metrics collected from test runs.
struct PerformanceMetrics {
    let name: String
    let iterations: Int
    let times: [TimeInterval]
    
    /// Average execution time across all iterations.
    var averageTime: TimeInterval {
        times.reduce(0, +) / Double(times.count)
    }
    
    /// Minimum execution time recorded.
    var minimumTime: TimeInterval {
        times.min() ?? 0
    }
    
    /// Maximum execution time recorded.
    var maximumTime: TimeInterval {
        times.max() ?? 0
    }
    
    /// Standard deviation of execution times.
    var standardDeviation: TimeInterval {
        let avg = averageTime
        let variance = times.reduce(0) { $0 + pow($1 - avg, 2) } / Double(times.count)
        return sqrt(variance)
    }
    
    /// Median execution time.
    var medianTime: TimeInterval {
        let sorted = times.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2
        } else {
            return sorted[mid]
        }
    }
    
    /// 95th percentile execution time.
    var p95Time: TimeInterval {
        percentile(95)
    }
    
    /// 99th percentile execution time.
    var p99Time: TimeInterval {
        percentile(99)
    }
    
    /// Throughput (requests per second based on average time).
    var throughput: Double {
        1.0 / averageTime
    }
    
    /// Number of samples collected.
    var sampleCount: Int {
        times.count
    }
    
    /// Calculate percentile value.
    private func percentile(_ p: Int) -> TimeInterval {
        let sorted = times.sorted()
        let index = Int(Double(sorted.count) * Double(p) / 100.0)
        return sorted[min(index, sorted.count - 1)]
    }
    
    /// Returns a formatted string representation of the metrics.
    var summary: String {
        """
        Performance Metrics: \(name)
        Iterations: \(iterations)
        Average: \(String(format: "%.4f", averageTime))s
        Min: \(String(format: "%.4f", minimumTime))s
        Max: \(String(format: "%.4f", maximumTime))s
        Std Dev: \(String(format: "%.4f", standardDeviation))s
        """
    }
}
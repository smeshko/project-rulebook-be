@testable import App
import XCTest
import Vapor
import Foundation

/// Comprehensive utilities for performance testing Phase 5 optimizations
final class PerformanceTestUtilities {
    
    // MARK: - Performance Targets (Phase 5 Goals)
    
    /// Performance targets defined for Phase 5
    struct PerformanceTargets {
        /// Target: 80% reduction in OpenAI API calls through caching
        static let apiCallReduction: Double = 0.80
        
        /// Target: Cache hit rate >70%
        static let cacheHitRate: Double = 0.70
        
        /// Target: P95 response time <200ms for cached requests
        static let p95ResponseTime: TimeInterval = 0.200
        
        /// Target: P95 response time <2000ms for uncached requests (baseline)
        static let p95UncachedResponseTime: TimeInterval = 2.000
        
        /// Target: Database query count reduction through eager loading
        static let queryReductionFactor: Double = 0.50
        
        /// Target: Memory usage per cache entry <10KB
        static let maxCacheEntrySize: Int = 10 * 1024
        
        /// Target: Cache eviction time <10ms
        static let cacheEvictionTime: TimeInterval = 0.010
    }
    
    // MARK: - Cost Calculation Utilities
    
    /// OpenAI API cost calculator for measuring savings
    struct APICostCalculator {
        /// Estimated cost per 1K tokens for gpt-4 (input)
        private static let inputCostPer1K: Double = 0.03
        
        /// Estimated cost per 1K tokens for gpt-4 (output)
        private static let outputCostPer1K: Double = 0.06
        
        /// Estimated average tokens per request (based on game rules generation)
        private static let averageInputTokens: Int = 1500
        private static let averageOutputTokens: Int = 2000
        
        /// Calculate cost for a single API call
        static func costPerRequest() -> Double {
            let inputCost = (Double(averageInputTokens) / 1000.0) * inputCostPer1K
            let outputCost = (Double(averageOutputTokens) / 1000.0) * outputCostPer1K
            return inputCost + outputCost
        }
        
        /// Calculate total cost for given number of requests
        static func totalCost(requests: Int) -> Double {
            return Double(requests) * costPerRequest()
        }
        
        /// Calculate savings with given cache hit rate
        static func savings(totalRequests: Int, cacheHitRate: Double) -> Double {
            let cachedRequests = Double(totalRequests) * cacheHitRate
            let uncachedRequests = Double(totalRequests) - cachedRequests
            
            let uncachedCost = totalCost(requests: Int(uncachedRequests))
            let totalCostWithoutCache = totalCost(requests: totalRequests)
            
            return totalCostWithoutCache - uncachedCost
        }
        
        /// Calculate percentage savings
        static func savingsPercentage(totalRequests: Int, cacheHitRate: Double) -> Double {
            let totalCost = totalCost(requests: totalRequests)
            let savedCost = savings(totalRequests: totalRequests, cacheHitRate: cacheHitRate)
            return (savedCost / totalCost) * 100.0
        }
    }
    
    // MARK: - Cache Performance Metrics
    
    /// Detailed cache performance metrics
    struct CachePerformanceMetrics {
        let totalRequests: Int
        let cacheHits: Int
        let cacheMisses: Int
        let averageHitTime: TimeInterval
        let averageMissTime: TimeInterval
        let p95HitTime: TimeInterval
        let p95MissTime: TimeInterval
        let hitTimes: [TimeInterval]
        let missTimes: [TimeInterval]
        let estimatedCostSavings: Double
        let memoryUsage: Int
        
        var hitRate: Double {
            guard totalRequests > 0 else { return 0.0 }
            return Double(cacheHits) / Double(totalRequests)
        }
        
        var hitRatePercentage: Double {
            return hitRate * 100.0
        }
        
        var performanceImprovement: Double {
            guard averageMissTime > 0 else { return 0.0 }
            return ((averageMissTime - averageHitTime) / averageMissTime) * 100.0
        }
        
        var summary: String {
            """
            Cache Performance Summary:
            Total Requests: \(totalRequests)
            Cache Hit Rate: \(String(format: "%.1f", hitRatePercentage))%
            Average Hit Time: \(String(format: "%.2f", averageHitTime * 1000))ms
            Average Miss Time: \(String(format: "%.2f", averageMissTime * 1000))ms
            P95 Hit Time: \(String(format: "%.2f", p95HitTime * 1000))ms
            P95 Miss Time: \(String(format: "%.2f", p95MissTime * 1000))ms
            Performance Improvement: \(String(format: "%.1f", performanceImprovement))%
            Estimated Cost Savings: $\(String(format: "%.4f", estimatedCostSavings))
            Memory Usage: \(memoryUsage) bytes
            """
        }
    }
    
    // MARK: - Repository Performance Metrics
    
    /// Database query performance metrics for N+1 prevention testing
    struct QueryPerformanceMetrics {
        let operationName: String
        let sequentialQueries: Int
        let eagerLoadQueries: Int
        let sequentialTime: TimeInterval
        let eagerLoadTime: TimeInterval
        let recordsProcessed: Int
        
        var queryReduction: Double {
            guard sequentialQueries > 0 else { return 0.0 }
            return Double(sequentialQueries - eagerLoadQueries) / Double(sequentialQueries)
        }
        
        var queryReductionPercentage: Double {
            return queryReduction * 100.0
        }
        
        var timeImprovement: Double {
            guard sequentialTime > 0 else { return 0.0 }
            return ((sequentialTime - eagerLoadTime) / sequentialTime) * 100.0
        }
        
        var summary: String {
            """
            Query Performance Summary (\(operationName)):
            Records Processed: \(recordsProcessed)
            Sequential Queries: \(sequentialQueries)
            Eager Load Queries: \(eagerLoadQueries)
            Query Reduction: \(String(format: "%.1f", queryReductionPercentage))%
            Sequential Time: \(String(format: "%.2f", sequentialTime * 1000))ms
            Eager Load Time: \(String(format: "%.2f", eagerLoadTime * 1000))ms
            Time Improvement: \(String(format: "%.1f", timeImprovement))%
            """
        }
    }
    
    // MARK: - Load Testing Results
    
    /// Comprehensive load testing metrics
    struct LoadTestResults {
        let testName: String
        let totalRequests: Int
        let concurrentUsers: Int
        let duration: TimeInterval
        let successfulRequests: Int
        let failedRequests: Int
        let responseTimes: [TimeInterval]
        let throughput: Double
        let errorRate: Double
        let cacheHitRate: Double
        
        var averageResponseTime: TimeInterval {
            guard !responseTimes.isEmpty else { return 0.0 }
            return responseTimes.reduce(0, +) / Double(responseTimes.count)
        }
        
        var p95ResponseTime: TimeInterval {
            guard !responseTimes.isEmpty else { return 0.0 }
            let sorted = responseTimes.sorted()
            let index = Int(Double(sorted.count) * 0.95)
            return sorted[min(index, sorted.count - 1)]
        }
        
        var p99ResponseTime: TimeInterval {
            guard !responseTimes.isEmpty else { return 0.0 }
            let sorted = responseTimes.sorted()
            let index = Int(Double(sorted.count) * 0.99)
            return sorted[min(index, sorted.count - 1)]
        }
        
        var successRate: Double {
            guard totalRequests > 0 else { return 0.0 }
            return Double(successfulRequests) / Double(totalRequests) * 100.0
        }
        
        var summary: String {
            """
            Load Test Results: \(testName)
            Total Requests: \(totalRequests)
            Concurrent Users: \(concurrentUsers)
            Duration: \(String(format: "%.1f", duration))s
            Success Rate: \(String(format: "%.1f", successRate))%
            Throughput: \(String(format: "%.1f", throughput)) req/s
            Average Response: \(String(format: "%.2f", averageResponseTime * 1000))ms
            P95 Response: \(String(format: "%.2f", p95ResponseTime * 1000))ms
            P99 Response: \(String(format: "%.2f", p99ResponseTime * 1000))ms
            Cache Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%
            Error Rate: \(String(format: "%.2f", errorRate))%
            """
        }
    }
    
    // MARK: - Test Data Generation
    
    /// Generate test prompts for LLM performance testing
    static func generateTestPrompts(count: Int = 100) -> [String] {
        let gameTypes = ["board game", "card game", "strategy game", "party game", "puzzle game"]
        let themes = ["medieval", "sci-fi", "fantasy", "modern", "historical"]
        let mechanics = ["dice rolling", "card drafting", "worker placement", "area control", "resource management"]
        
        return (0..<count).map { index in
            let gameType = gameTypes[index % gameTypes.count]
            let theme = themes[index % themes.count]
            let mechanic = mechanics[index % mechanics.count]
            
            return """
            Generate rules for a \(theme) \(gameType) with \(mechanic) mechanics.
            The game should be suitable for 2-6 players and take 30-90 minutes to play.
            Include setup instructions, gameplay mechanics, winning conditions, and any special rules.
            Make the rules clear and comprehensive for new players.
            Request #\(index + 1)
            """
        }
    }
    
    /// Generate test user data for repository performance testing
    static func generateTestUsers(count: Int = 1000) -> [(email: String, name: String)] {
        return (0..<count).map { index in
            (
                email: "testuser\(index)@example.com",
                name: "Test User \(index)"
            )
        }
    }
    
    // MARK: - Performance Assertion Helpers
    
    /// Assert cache hit rate meets target
    static func assertCacheHitRate(_ metrics: CachePerformanceMetrics, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(metrics.hitRate, PerformanceTargets.cacheHitRate, 
            "Cache hit rate (\(String(format: "%.1f", metrics.hitRatePercentage))%) below target (\(String(format: "%.1f", PerformanceTargets.cacheHitRate * 100))%)",
            file: file, line: line)
    }
    
    /// Assert P95 response time meets target
    static func assertP95ResponseTime(_ responseTime: TimeInterval, target: TimeInterval = PerformanceTargets.p95ResponseTime, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(responseTime, target,
            "P95 response time (\(String(format: "%.2f", responseTime * 1000))ms) exceeds target (\(String(format: "%.2f", target * 1000))ms)",
            file: file, line: line)
    }
    
    /// Assert cost savings meet target
    static func assertCostSavings(_ savings: Double, totalRequests: Int, file: StaticString = #filePath, line: UInt = #line) {
        let totalCost = APICostCalculator.totalCost(requests: totalRequests)
        let savingsPercentage = (savings / totalCost) * 100.0
        
        XCTAssertGreaterThan(savingsPercentage, PerformanceTargets.apiCallReduction * 100.0,
            "Cost savings (\(String(format: "%.1f", savingsPercentage))%) below target (\(String(format: "%.1f", PerformanceTargets.apiCallReduction * 100))%)",
            file: file, line: line)
    }
    
    /// Assert query reduction meets target
    static func assertQueryReduction(_ metrics: QueryPerformanceMetrics, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(metrics.queryReduction, PerformanceTargets.queryReductionFactor,
            "Query reduction (\(String(format: "%.1f", metrics.queryReductionPercentage))%) below target (\(String(format: "%.1f", PerformanceTargets.queryReductionFactor * 100))%)",
            file: file, line: line)
    }
    
    /// Assert throughput meets minimum requirements
    static func assertThroughput(_ throughput: Double, minimum: Double = 10.0, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThan(throughput, minimum,
            "Throughput (\(String(format: "%.1f", throughput)) req/s) below minimum (\(String(format: "%.1f", minimum)) req/s)",
            file: file, line: line)
    }
    
    /// Assert memory usage per cache entry is reasonable
    static func assertMemoryUsage(_ bytesPerEntry: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertLessThan(bytesPerEntry, PerformanceTargets.maxCacheEntrySize,
            "Memory usage per cache entry (\(bytesPerEntry) bytes) exceeds target (\(PerformanceTargets.maxCacheEntrySize) bytes)",
            file: file, line: line)
    }
    
    // MARK: - Benchmark Utilities
    
    /// Run a benchmark with warmup and statistical analysis
    static func runBenchmark<T>(
        name: String,
        warmupIterations: Int = 10,
        measureIterations: Int = 100,
        operation: () async throws -> T
    ) async throws -> PerformanceMetrics {
        // Warmup phase
        for _ in 0..<warmupIterations {
            _ = try await operation()
        }
        
        // Measurement phase
        var times: [TimeInterval] = []
        for _ in 0..<measureIterations {
            let startTime = Date()
            _ = try await operation()
            let endTime = Date()
            times.append(endTime.timeIntervalSince(startTime))
        }
        
        return PerformanceMetrics(
            name: name,
            iterations: measureIterations,
            times: times
        )
    }
    
    /// Create realistic load test scenario
    static func simulateRealisticLoad(
        requests: Int,
        concurrency: Int,
        operation: @escaping @Sendable () async throws -> TimeInterval
    ) async throws -> LoadTestResults {
        let startTime = Date()
        var responseTimes: [TimeInterval] = []
        var successCount = 0
        var failureCount = 0
        
        // Run concurrent operations in batches
        let batchSize = concurrency
        let batches = (requests + batchSize - 1) / batchSize
        
        for batch in 0..<batches {
            let batchStart = batch * batchSize
            let batchEnd = min(batchStart + batchSize, requests)
            let batchRequests = batchEnd - batchStart
            
            await withTaskGroup(of: Result<TimeInterval, Error>.self) { group in
                for _ in 0..<batchRequests {
                    group.addTask {
                        do {
                            let responseTime = try await operation()
                            return .success(responseTime)
                        } catch {
                            return .failure(error)
                        }
                    }
                }
                
                for await result in group {
                    switch result {
                    case .success(let responseTime):
                        responseTimes.append(responseTime)
                        successCount += 1
                    case .failure:
                        failureCount += 1
                    }
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        let throughput = Double(successCount) / duration
        let errorRate = Double(failureCount) / Double(requests) * 100.0
        
        return LoadTestResults(
            testName: "Realistic Load Test",
            totalRequests: requests,
            concurrentUsers: concurrency,
            duration: duration,
            successfulRequests: successCount,
            failedRequests: failureCount,
            responseTimes: responseTimes,
            throughput: throughput,
            errorRate: errorRate,
            cacheHitRate: 0.0 // To be set by caller based on cache statistics
        )
    }
}

// MARK: - Extensions

extension PerformanceMetrics {
    /// Enhanced summary with Phase 5 specific metrics
    var phase5Summary: String {
        """
        \(summary)
        P95: \(String(format: "%.4f", p95Time))s
        P99: \(String(format: "%.4f", p99Time))s
        Throughput: \(String(format: "%.1f", throughput)) ops/sec
        """
    }
    
    /// Check if performance meets Phase 5 targets
    func meetsPhase5Targets(for targetType: PerformanceTestUtilities.TargetType) -> Bool {
        switch targetType {
        case .cachedResponse:
            return p95Time < PerformanceTestUtilities.PerformanceTargets.p95ResponseTime
        case .uncachedResponse:
            return p95Time < PerformanceTestUtilities.PerformanceTargets.p95UncachedResponseTime
        case .cacheOperation:
            return p95Time < PerformanceTestUtilities.PerformanceTargets.cacheEvictionTime
        }
    }
}

extension PerformanceTestUtilities {
    enum TargetType {
        case cachedResponse
        case uncachedResponse
        case cacheOperation
    }
}
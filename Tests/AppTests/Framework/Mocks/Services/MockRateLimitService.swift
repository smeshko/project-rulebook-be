@testable import App
import Foundation
import Vapor

/// Mock Rate Limit service for testing rate limiting scenarios.
///
/// This service provides utilities to manipulate the rate limit storage
/// for testing different rate limiting scenarios without requiring actual
/// HTTP requests to trigger rate limits.
final class MockRateLimitService: @unchecked Sendable {
    private let application: Application
    private let logger: Logger
    
    init(app: Application) {
        self.application = app
        self.logger = app.logger
    }
    
    // MARK: - Test Utilities
    
    /// Simulate requests to trigger rate limiting for a specific operation type and client IP.
    ///
    /// - Parameters:
    ///   - type: The rate limit type to simulate requests for
    ///   - clientIP: The client IP address to use
    ///   - count: Number of requests to simulate
    ///   - timeSpread: Time span over which to spread the requests (default: 0 for all at once)
    func simulateRequests(
        type: RateLimitType,
        clientIP: String,
        count: Int,
        timeSpread: TimeInterval = 0
    ) async {
        let operationKey = "\(type.rawValue)_\(clientIP)"
        let baseTime = Date()
        
        for i in 0..<count {
            let requestTime: Date
            if timeSpread > 0 {
                let offset = (timeSpread / Double(count)) * Double(i)
                requestTime = baseTime.addingTimeInterval(-offset)
            } else {
                requestTime = baseTime
            }
            
            await RateLimitStorage.shared.record(operationKey: operationKey, at: requestTime)
        }
        
        logger.info("Simulated \(count) requests for \(type.rawValue) from IP \(clientIP)")
    }
    
    /// Fill up the rate limit for a specific operation type to the maximum.
    ///
    /// - Parameters:
    ///   - type: The rate limit type to fill
    ///   - clientIP: The client IP address to use
    ///   - configuration: The rate limit configuration to use for determining limits
    func fillRateLimit(
        type: RateLimitType,
        clientIP: String,
        configuration: RateLimitConfiguration
    ) async {
        let maxRequests = getMaxRequests(for: type, configuration: configuration)
        await simulateRequests(type: type, clientIP: clientIP, count: maxRequests)
    }
    
    /// Check if a client would be rate limited for a specific operation type.
    ///
    /// - Parameters:
    ///   - type: The rate limit type to check
    ///   - clientIP: The client IP address to check
    ///   - configuration: The rate limit configuration to use
    /// - Returns: True if the client would be rate limited
    func wouldBeRateLimited(
        type: RateLimitType,
        clientIP: String,
        configuration: RateLimitConfiguration
    ) async -> Bool {
        let operationKey = "\(type.rawValue)_\(clientIP)"
        let windowSeconds = getWindowSeconds(for: type, configuration: configuration)
        let maxRequests = getMaxRequests(for: type, configuration: configuration)
        
        let cutoffTime = Date().addingTimeInterval(-Double(windowSeconds))
        let currentCount = await RateLimitStorage.shared.getCount(for: operationKey, since: cutoffTime)
        
        return currentCount >= maxRequests
    }
    
    /// Get the current request count for a specific operation and client.
    ///
    /// - Parameters:
    ///   - type: The rate limit type to check
    ///   - clientIP: The client IP address to check
    ///   - configuration: The rate limit configuration to use
    /// - Returns: Current number of requests in the time window
    func getCurrentCount(
        type: RateLimitType,
        clientIP: String,
        configuration: RateLimitConfiguration
    ) async -> Int {
        let operationKey = "\(type.rawValue)_\(clientIP)"
        let windowSeconds = getWindowSeconds(for: type, configuration: configuration)
        let cutoffTime = Date().addingTimeInterval(-Double(windowSeconds))
        
        return await RateLimitStorage.shared.getCount(for: operationKey, since: cutoffTime)
    }
    
    /// Reset all rate limit data.
    func resetAllRateLimits() async {
        let currentTime = Date()
        // Use a time far in the future to effectively clear all entries
        await RateLimitStorage.shared.cleanup(olderThan: currentTime.addingTimeInterval(1))
        logger.info("All rate limit data reset")
    }
    
    /// Get rate limit statistics for testing.
    func getStatistics() async -> [String: String] {
        // Return mock statistics for testing purposes
        return [
            "total_tracked_operations": "0",
            "total_requests": "0",
            "mock_service": "true"
        ]
    }
    
    // MARK: - Test Scenarios
    
    /// Set up a scenario where the client is just below the rate limit.
    ///
    /// - Parameters:
    ///   - type: The rate limit type
    ///   - clientIP: The client IP address
    ///   - configuration: The rate limit configuration
    func setupNearLimitScenario(
        type: RateLimitType,
        clientIP: String,
        configuration: RateLimitConfiguration
    ) async {
        let maxRequests = getMaxRequests(for: type, configuration: configuration)
        let requestsToSimulate = max(1, maxRequests - 2) // Leave 1-2 requests before limit
        await simulateRequests(type: type, clientIP: clientIP, count: requestsToSimulate)
    }
    
    /// Set up a scenario where the client has exceeded the rate limit.
    ///
    /// - Parameters:
    ///   - type: The rate limit type
    ///   - clientIP: The client IP address
    ///   - configuration: The rate limit configuration
    func setupExceededLimitScenario(
        type: RateLimitType,
        clientIP: String,
        configuration: RateLimitConfiguration
    ) async {
        let maxRequests = getMaxRequests(for: type, configuration: configuration)
        let requestsToSimulate = maxRequests + 5 // Exceed by 5 requests
        await simulateRequests(type: type, clientIP: clientIP, count: requestsToSimulate)
    }
    
    // MARK: - Private Helpers
    
    private func getMaxRequests(for type: RateLimitType, configuration: RateLimitConfiguration) -> Int {
        switch type {
        case .imageAnalysis:
            return configuration.imageAnalysisLimit
        case .rulesGeneration:
            return configuration.rulesGenerationLimit
        case .admin:
            return configuration.adminLimit
        case .api:
            return configuration.apiLimit
        case .general:
            return configuration.generalLimit
        case .waitlist:
            return configuration.waitlistLimit
        }
    }

    private func getWindowSeconds(for type: RateLimitType, configuration: RateLimitConfiguration) -> Int {
        switch type {
        case .imageAnalysis:
            return configuration.imageAnalysisWindow
        case .rulesGeneration:
            return configuration.rulesGenerationWindow
        case .admin:
            return configuration.adminWindow
        case .api:
            return configuration.apiWindow
        case .general:
            return configuration.generalWindow
        case .waitlist:
            return configuration.waitlistWindow
        }
    }
}

// MARK: - Application Extension for Test Access

extension Application {
    /// Mock rate limit service for testing.
    var mockRateLimit: MockRateLimitService {
        MockRateLimitService(app: self)
    }
}
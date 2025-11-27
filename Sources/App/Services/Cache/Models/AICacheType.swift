import Foundation

/// Types of AI operations that can be cached
public enum AICacheType: String, CaseIterable, Sendable {
    case rulesGeneration = "rules_generation"

    /// Returns the appropriate TTL for this cache type
    /// - Parameter config: The cache configuration to use
    /// - Returns: TTL in seconds
    func getTTL(from config: CacheConfiguration) -> TimeInterval {
        return config.rulesGenerationTTL
    }

    /// Returns a human-readable description
    var description: String {
        return "Rules Generation"
    }
}
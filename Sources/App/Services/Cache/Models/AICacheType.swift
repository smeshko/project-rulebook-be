import Foundation

/// Types of AI operations that can be cached
public enum AICacheType: String, CaseIterable, Sendable {
    case rulesGeneration = "rules_generation"
    case imageAnalysis = "image_analysis"
    
    /// Returns the appropriate TTL for this cache type
    /// - Parameter config: The cache configuration to use
    /// - Returns: TTL in seconds
    func getTTL(from config: CacheConfiguration) -> TimeInterval {
        switch self {
        case .rulesGeneration:
            return config.rulesGenerationTTL
        case .imageAnalysis:
            return config.imageAnalysisTTL
        }
    }
    
    /// Returns a human-readable description
    var description: String {
        switch self {
        case .rulesGeneration:
            return "Rules Generation"
        case .imageAnalysis:
            return "Image Analysis"
        }
    }
}
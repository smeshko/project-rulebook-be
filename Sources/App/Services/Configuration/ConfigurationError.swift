import Vapor

enum ConfigurationError: LocalizedError, CustomStringConvertible {
    case missingRequired(key: String, suggestion: String)
    case invalidFormat(key: String, expected: String, got: String)
    case validationFailed(component: String, reason: String)
    
    var description: String {
        switch self {
        case .missingRequired(let key, let suggestion):
            return "Missing required environment variable: \(key). \(suggestion)"
        case .invalidFormat(let key, let expected, let got):
            return "Invalid format for \(key): expected \(expected), got \(got)"
        case .validationFailed(let component, let reason):
            return "Configuration validation failed for \(component): \(reason)"
        }
    }
    
    var errorDescription: String? {
        return description
    }
}
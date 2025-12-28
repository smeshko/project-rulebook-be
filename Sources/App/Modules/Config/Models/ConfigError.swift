import Vapor

enum ConfigError: AppError {
    case notFound(String)
    case keyAlreadyExists(String)
    case invalidValue(String)

    var status: HTTPResponseStatus {
        switch self {
        case .notFound: return .notFound
        case .keyAlreadyExists: return .conflict
        case .invalidValue: return .badRequest
        }
    }

    var reason: String {
        switch self {
        case .notFound(let key): return "Config key '\(key)' not found"
        case .keyAlreadyExists(let key): return "Config key '\(key)' already exists"
        case .invalidValue(let msg): return msg
        }
    }

    var identifier: String {
        switch self {
        case .notFound: return "config_not_found"
        case .keyAlreadyExists: return "config_key_exists"
        case .invalidValue: return "config_invalid_value"
        }
    }
}

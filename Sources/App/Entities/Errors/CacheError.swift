import Foundation

/// Errors that can occur during cache operations
public enum CacheError: Error, LocalizedError {
    case retrievalFailed(Error)
    case storageFailed(Error)
    case deletionFailed(Error)
    case flushFailed(Error)
    case queryFailed(Error)
    case operationFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .retrievalFailed(let error):
            return "Cache retrieval failed: \(error.localizedDescription)"
        case .storageFailed(let error):
            return "Cache storage failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Cache deletion failed: \(error.localizedDescription)"
        case .flushFailed(let error):
            return "Cache flush failed: \(error.localizedDescription)"
        case .queryFailed(let error):
            return "Cache query failed: \(error.localizedDescription)"
        case .operationFailed(let error):
            return "Cache operation failed: \(error.localizedDescription)"
        }
    }
}
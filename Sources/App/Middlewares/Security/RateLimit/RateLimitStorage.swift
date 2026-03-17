import Foundation

actor RateLimitStorage {
    static let shared = RateLimitStorage()
    
    private var requests: [String: [Date]] = [:]
    
    private init() {}
    
    func record(operationKey: String, at time: Date) {
        requests[operationKey, default: []].append(time)
    }
    
    func getCount(for operationKey: String, since cutoffTime: Date) -> Int {
        return requests[operationKey]?.filter { $0 >= cutoffTime }.count ?? 0
    }
    
    func getOldestTimestamp(for operationKey: String, since cutoffTime: Date) -> Date? {
        return requests[operationKey]?.filter { $0 >= cutoffTime }.min()
    }

    func cleanup(olderThan cutoffTime: Date) {
        for key in requests.keys {
            requests[key] = requests[key]?.filter { $0 >= cutoffTime }
            if requests[key]?.isEmpty == true {
                requests[key] = nil
            }
        }
    }
    
    /// Returns current statistics for monitoring
    func getStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        stats["total_tracked_operations"] = requests.count
        stats["total_requests"] = requests.values.reduce(0) { $0 + $1.count }
        
        // Per-type statistics
        for type in RateLimitType.allCases {
            let typeRequests = requests.keys
                .filter { $0.hasPrefix("\(type.rawValue)_") }
                .compactMap { requests[$0] }
                .reduce(0) { $0 + $1.count }
            stats["\(type.rawValue)_requests"] = typeRequests
        }
        
        return stats
    }
}
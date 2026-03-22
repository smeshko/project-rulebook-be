import Foundation
import Vapor

public enum CacheAdmin {}

public extension CacheAdmin {
    enum Statistics {
        public struct Response: Content, Equatable {
            public let statistics: CacheStatistics
            public let entriesByType: [String: [String]]
            public let timestamp: Date
            
            public init(
                statistics: CacheStatistics,
                entriesByType: [String: [String]],
                timestamp: Date
            ) {
                self.statistics = statistics
                self.entriesByType = entriesByType
                self.timestamp = timestamp
            }
            
            enum CodingKeys: String, CodingKey {
                case statistics
                case entriesByType = "entries_by_type"
                case timestamp
            }
        }
    }

    enum Clear {
        public struct Response: Content, Equatable {
            public let entriesRemoved: Int
            public let remainingEntries: Int
            public let timestamp: Date
            
            public init(
                entriesRemoved: Int,
                remainingEntries: Int,
                timestamp: Date
            ) {
                self.entriesRemoved = entriesRemoved
                self.remainingEntries = remainingEntries
                self.timestamp = timestamp
            }
            
            enum CodingKeys: String, CodingKey {
                case entriesRemoved = "entries_removed"
                case remainingEntries = "remaining_entries"
                case timestamp
            }
        }
    }

    enum Entries {
        public struct Response: Content, Equatable {
            public let entries: [EntryInfo]
            public let entriesByType: [String: [String]]
            public let totalCount: Int
            public let timestamp: Date
            
            public init(
                entries: [EntryInfo],
                entriesByType: [String: [String]],
                totalCount: Int,
                timestamp: Date
            ) {
                self.entries = entries
                self.entriesByType = entriesByType
                self.totalCount = totalCount
                self.timestamp = timestamp
            }
            
            enum CodingKeys: String, CodingKey {
                case entries
                case entriesByType = "entries_by_type"
                case totalCount = "total_count"
                case timestamp
            }
        }
        
        public struct EntryInfo: Content, Equatable {
            public let key: String
            public let age: TimeInterval
            public let ttlRemaining: TimeInterval
            public let hitCount: Int
            public let lastAccessed: TimeInterval
            public let expired: Bool
            
            public init(
                key: String,
                age: TimeInterval,
                ttlRemaining: TimeInterval,
                hitCount: Int,
                lastAccessed: TimeInterval,
                expired: Bool
            ) {
                self.key = key
                self.age = age
                self.ttlRemaining = ttlRemaining
                self.hitCount = hitCount
                self.lastAccessed = lastAccessed
                self.expired = expired
            }
            
            enum CodingKeys: String, CodingKey {
                case key
                case age
                case ttlRemaining = "ttl_remaining"
                case hitCount = "hit_count"
                case lastAccessed = "last_accessed"
                case expired
            }
        }
    }

    enum Cleanup {
        public struct Response: Content, Equatable {
            public let entriesRemoved: Int
            public let remainingEntries: Int
            public let timestamp: Date
            
            public init(
                entriesRemoved: Int,
                remainingEntries: Int,
                timestamp: Date
            ) {
                self.entriesRemoved = entriesRemoved
                self.remainingEntries = remainingEntries
                self.timestamp = timestamp
            }
            
            enum CodingKeys: String, CodingKey {
                case entriesRemoved = "entries_removed"
                case remainingEntries = "remaining_entries"
                case timestamp
            }
        }
    }
    
    enum Health {
        public enum Status: String, Codable, Equatable, Sendable {
            case healthy = "healthy"
            case warning = "warning"
            case critical = "critical"
        }
        
        public struct Response: Content, Equatable {
            public let status: Status
            public let statistics: CacheStatistics
            public let issues: [String]
            public let recommendations: [String]
            public let timestamp: Date
            
            public init(
                status: Status,
                statistics: CacheStatistics,
                issues: [String],
                recommendations: [String],
                timestamp: Date
            ) {
                self.status = status
                self.statistics = statistics
                self.issues = issues
                self.recommendations = recommendations
                self.timestamp = timestamp
            }
        }
    }
    
    enum Warm {
        public struct Response: Content, Equatable {
            public let status: String
            public let gamesToWarm: Int
            public let timestamp: Date

            public init(
                status: String,
                gamesToWarm: Int,
                timestamp: Date
            ) {
                self.status = status
                self.gamesToWarm = gamesToWarm
                self.timestamp = timestamp
            }

            enum CodingKeys: String, CodingKey {
                case status
                case gamesToWarm = "games_to_warm"
                case timestamp
            }
        }
    }

    enum RedisHealth {
        public enum Status: String, Codable, Equatable, Sendable {
            case healthy = "healthy"
            case warning = "warning"  
            case critical = "critical"
        }
        
        public struct Response: Content, Equatable {
            public let status: Status
            public let connected: Bool
            public let latencyMs: Double?
            public let issues: [String]
            public let timestamp: Date
            
            public init(
                status: Status,
                connected: Bool,
                latencyMs: Double?,
                issues: [String],
                timestamp: Date
            ) {
                self.status = status
                self.connected = connected
                self.latencyMs = latencyMs
                self.issues = issues
                self.timestamp = timestamp
            }
            
            enum CodingKeys: String, CodingKey {
                case status
                case connected
                case latencyMs = "latency_ms"
                case issues
                case timestamp
            }
        }
    }
}
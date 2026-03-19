import Vapor

public enum Health {}

public extension Health {
    enum Check {
        public struct Checks: Content, Equatable, Sendable {
            public let database: String
            public let redis: String

            public init(database: String, redis: String) {
                self.database = database
                self.redis = redis
            }
        }

        public struct Response: Content, Equatable, Sendable {
            public let status: String
            public let timestamp: String
            public let checks: Checks

            public init(status: String, timestamp: String, checks: Checks) {
                self.status = status
                self.timestamp = timestamp
                self.checks = checks
            }
        }
    }
}

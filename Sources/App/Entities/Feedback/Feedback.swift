import Foundation
import Vapor

public enum Feedback {}

public extension Feedback {
    enum Submit {
        public struct Request: Codable, Equatable, Sendable {
            public let rulesSummaryId: UUID
            public let gameTitle: String
            public let feedbackType: String
            public let description: String
            public let userContact: String?

            public init(
                rulesSummaryId: UUID,
                gameTitle: String,
                feedbackType: String,
                description: String,
                userContact: String? = nil
            ) {
                self.rulesSummaryId = rulesSummaryId
                self.gameTitle = gameTitle
                self.feedbackType = feedbackType
                self.description = description
                self.userContact = userContact
            }
        }

        public struct Response: Codable, Equatable, Sendable {
            public let success: Bool
            public let feedbackId: UUID?

            public init(success: Bool, feedbackId: UUID? = nil) {
                self.success = success
                self.feedbackId = feedbackId
            }
        }
    }

    enum Detail {
        public struct Response: Codable, Equatable, Sendable {
            public let id: UUID
            public let rulesSummaryId: UUID?
            public let gameTitle: String
            public let feedbackType: String
            public let description: String
            public let userContact: String?
            public let status: String
            public let createdAt: Date?

            public init(
                id: UUID,
                rulesSummaryId: UUID?,
                gameTitle: String,
                feedbackType: String,
                description: String,
                userContact: String?,
                status: String,
                createdAt: Date?
            ) {
                self.id = id
                self.rulesSummaryId = rulesSummaryId
                self.gameTitle = gameTitle
                self.feedbackType = feedbackType
                self.description = description
                self.userContact = userContact
                self.status = status
                self.createdAt = createdAt
            }
        }
    }

    enum List {
        public struct Response: Codable, Equatable, Sendable {
            public let items: [Feedback.Detail.Response]
            public let total: Int
            public let page: Int
            public let limit: Int

            public init(items: [Feedback.Detail.Response], total: Int, page: Int, limit: Int) {
                self.items = items
                self.total = total
                self.page = page
                self.limit = limit
            }
        }
    }
}

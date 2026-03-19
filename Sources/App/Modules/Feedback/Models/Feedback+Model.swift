import Vapor

// MARK: - Content Conformance

extension Feedback.Submit.Request: Content {}
extension Feedback.Submit.Response: Content {}
extension Feedback.Detail.Response: Content {}
extension Feedback.List.Response: Content {}

// MARK: - Model to DTO Conversion

extension Feedback.Detail.Response {
    init(from model: FeedbackModel) throws {
        self.init(
            id: try model.requireID(),
            rulesSummaryId: model.rulesSummaryId,
            gameTitle: model.gameTitle,
            feedbackType: model.feedbackType.rawValue,
            description: model.description,
            userContact: model.userContact,
            status: model.status.rawValue,
            createdAt: model.createdAt
        )
    }
}

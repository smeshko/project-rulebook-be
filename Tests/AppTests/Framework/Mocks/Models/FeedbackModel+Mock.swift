@testable import App
import Foundation

extension FeedbackModel {
    static func mock(
        id: UUID? = UUID(),
        rulesSummaryId: UUID? = UUID(),
        gameTitle: String = "Test Game",
        feedbackType: FeedbackType = .incorrect,
        description: String = "Test feedback description",
        userContact: String? = nil,
        status: FeedbackStatus = .pending
    ) -> FeedbackModel {
        FeedbackModel(
            id: id,
            rulesSummaryId: rulesSummaryId,
            gameTitle: gameTitle,
            feedbackType: feedbackType,
            description: description,
            userContact: userContact,
            status: status
        )
    }
}

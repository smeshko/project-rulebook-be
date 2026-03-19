import Vapor

struct FeedbackController {

    func submit(_ req: Request) async throws -> Feedback.Submit.Response {
        let input = try req.content.decode(Feedback.Submit.Request.self)

        // Validate gameTitle
        let trimmedGameTitle = input.gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGameTitle.isEmpty else {
            throw FeedbackError.gameTitleRequired
        }
        guard trimmedGameTitle.count <= 500 else {
            throw FeedbackError.gameTitleTooLong
        }

        // Validate description
        let trimmedDescription = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            throw FeedbackError.descriptionRequired
        }
        guard trimmedDescription.count <= 5000 else {
            throw FeedbackError.descriptionTooLong
        }

        // Validate feedbackType
        guard let feedbackType = FeedbackType(rawValue: input.feedbackType) else {
            throw FeedbackError.invalidFeedbackType
        }

        // Normalize optional userContact
        let trimmedContact = input.userContact?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userContact: String? = (trimmedContact?.isEmpty == false) ? trimmedContact : nil

        // Create model
        let model = FeedbackModel(
            rulesSummaryId: input.rulesSummaryId,
            gameTitle: trimmedGameTitle,
            feedbackType: feedbackType,
            description: trimmedDescription,
            userContact: userContact,
            status: .pending
        )

        try await req.repositories.feedback.create(model)

        let feedbackId = try model.requireID()

        req.logger.info("Feedback submitted", metadata: [
            "feedbackId": .string(feedbackId.uuidString),
            "gameTitle": .string(trimmedGameTitle),
            "feedbackType": .string(feedbackType.rawValue),
            "hasContact": .string(userContact != nil ? "true" : "false")
        ])

        return Feedback.Submit.Response(
            success: true,
            feedbackId: feedbackId
        )
    }
}

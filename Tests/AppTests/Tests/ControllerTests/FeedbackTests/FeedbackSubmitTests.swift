@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct FeedbackSubmitTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let submitPath = "api/v1/feedback"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Happy Path

    @Test("Successful feedback submission with all fields", .tags(.p0Critical, .feedback, .integration))
    func submitHappyPath() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Catan",
            feedbackType: "incorrect",
            description: "The setup instructions are missing the initial settlement placement rules.",
            userContact: "user@example.com"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(Feedback.Submit.Response.self, res) { content in
                #expect(content.success == true)
                #expect(content.feedbackId != nil)
            }

            // Verify feedback was persisted
            let feedbacks = await testWorld.feedbacks.feedbacks
            #expect(feedbacks.count == 1)
            #expect(feedbacks.first?.gameTitle == "Catan")
            #expect(feedbacks.first?.feedbackType == .incorrect)
            #expect(feedbacks.first?.status == .pending)
            #expect(feedbacks.first?.userContact == "user@example.com")
        })
    }

    @Test("Successful submission without optional userContact", .tags(.p0Critical, .feedback, .integration))
    func submitWithoutContact() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Root",
            feedbackType: "incomplete",
            description: "Missing faction-specific setup rules."
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)
            expectContent(Feedback.Submit.Response.self, res) { content in
                #expect(content.success == true)
                #expect(content.feedbackId != nil)
            }

            let feedbacks = await testWorld.feedbacks.feedbacks
            #expect(feedbacks.count == 1)
            #expect(feedbacks.first?.userContact == nil)
        })
    }

    // MARK: - Validation: Game Title

    @Test("Submission fails with empty gameTitle", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithEmptyGameTitle() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "",
            feedbackType: "incorrect",
            description: "Some description"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.gameTitleRequired)
        })
    }

    @Test("Submission fails with whitespace-only gameTitle", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithWhitespaceGameTitle() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "   ",
            feedbackType: "incorrect",
            description: "Some description"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.gameTitleRequired)
        })
    }

    @Test("Submission fails with gameTitle exceeding 500 characters", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithGameTitleTooLong() async throws {
        await testWorld.resetAll()

        let longGameTitle = String(repeating: "a", count: 501)
        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: longGameTitle,
            feedbackType: "incorrect",
            description: "Some description"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.gameTitleTooLong)
        })
    }

    // MARK: - Validation: Description

    @Test("Submission fails with empty description", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithEmptyDescription() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Catan",
            feedbackType: "incorrect",
            description: ""
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.descriptionRequired)
        })
    }

    @Test("Submission fails with description exceeding 5000 characters", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithDescriptionTooLong() async throws {
        await testWorld.resetAll()

        let longDescription = String(repeating: "a", count: 5001)
        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Catan",
            feedbackType: "incorrect",
            description: longDescription
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.descriptionTooLong)
        })
    }

    // MARK: - Validation: Feedback Type

    @Test("Submission fails with invalid feedbackType", .tags(.p1Core, .feedback, .integration))
    func submitFailsWithInvalidFeedbackType() async throws {
        await testWorld.resetAll()

        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Catan",
            feedbackType: "wrong",
            description: "Some description"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            expectResponseError(res, FeedbackError.invalidFeedbackType)
        })
    }

    @Test("All valid feedbackType values succeed", .tags(.p1Core, .feedback, .integration))
    func submitSucceedsWithAllValidFeedbackTypes() async throws {
        for feedbackType in ["incorrect", "incomplete", "other"] {
            await testWorld.resetAll()

            let request = Feedback.Submit.Request(
                rulesSummaryId: UUID(),
                gameTitle: "Catan",
                feedbackType: feedbackType,
                description: "Test feedback for type \(feedbackType)"
            )

            try await app.test(.POST, submitPath, beforeRequest: { req in
                try req.content.encode(request)
            }, afterResponse: { res in
                #expect(res.status == .ok)
                expectContent(Feedback.Submit.Response.self, res) { content in
                    #expect(content.success == true)
                }
            })
        }
    }

    // MARK: - Edge Cases

    @Test("Description at exactly 5000 characters succeeds", .tags(.p2Extended, .feedback, .integration))
    func submitSucceedsWithMaxLengthDescription() async throws {
        await testWorld.resetAll()

        let maxDescription = String(repeating: "a", count: 5000)
        let request = Feedback.Submit.Request(
            rulesSummaryId: UUID(),
            gameTitle: "Catan",
            feedbackType: "other",
            description: maxDescription
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Feedback.Submit.Response.self, res) { content in
                #expect(content.success == true)
            }
        })
    }

    @Test("Feedback is persisted with correct data after submission", .tags(.p2Extended, .feedback, .integration))
    func submitPersistsCorrectData() async throws {
        await testWorld.resetAll()

        let rulesSummaryId = UUID()
        let request = Feedback.Submit.Request(
            rulesSummaryId: rulesSummaryId,
            gameTitle: "  Catan  ",
            feedbackType: "incomplete",
            description: "  Missing rules for 5-6 player expansion.  ",
            userContact: "tester@example.com"
        )

        try await app.test(.POST, submitPath, beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async throws in
            #expect(res.status == .ok)

            let feedbacks = await testWorld.feedbacks.feedbacks
            #expect(feedbacks.count == 1)

            let feedback = feedbacks.first!
            #expect(feedback.rulesSummaryId == rulesSummaryId)
            #expect(feedback.gameTitle == "Catan") // trimmed
            #expect(feedback.feedbackType == .incomplete)
            #expect(feedback.description == "Missing rules for 5-6 player expansion.") // trimmed
            #expect(feedback.userContact == "tester@example.com")
            #expect(feedback.status == .pending)
        })
    }
}

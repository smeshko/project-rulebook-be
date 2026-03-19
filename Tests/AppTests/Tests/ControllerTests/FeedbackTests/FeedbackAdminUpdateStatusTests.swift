@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct FeedbackAdminUpdateStatusTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let adminPath = "api/v1/admin/feedback"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - P0 Critical Tests

    @Test("Admin can update status from pending to reviewed", .tags(.p0Critical, .feedback, .integration))
    func updatePendingToReviewed() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let feedback = FeedbackModel.mock(status: .pending)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(Feedback.Detail.Response.self, response) { detail in
                #expect(detail.id == feedbackId)
                #expect(detail.status == "reviewed")
            }
        })
    }

    @Test("Admin can update status from reviewed to resolved", .tags(.p0Critical, .feedback, .integration))
    func updateReviewedToResolved() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let feedback = FeedbackModel.mock(status: .reviewed)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "resolved")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(Feedback.Detail.Response.self, response) { detail in
                #expect(detail.id == feedbackId)
                #expect(detail.status == "resolved")
            }
        })
    }

    @Test("Update fails for unauthenticated request", .tags(.p0Critical, .feedback, .integration))
    func updateUnauthenticatedFails() async throws {
        await testWorld.resetAll()

        let feedback = FeedbackModel.mock(status: .pending)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", content: request, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    @Test("Update fails for non-admin user", .tags(.p0Critical, .feedback, .integration))
    func updateNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        let feedback = FeedbackModel.mock(status: .pending)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: nonAdmin, content: request, afterResponse: { response in
            #expect(response.status == .unauthorized)
        })
    }

    // MARK: - P1 Core Tests

    @Test("Update fails with invalid status value", .tags(.p1Core, .feedback, .integration))
    func updateInvalidStatusFails() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let feedback = FeedbackModel.mock(status: .pending)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "invalid")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .badRequest)
        })
    }

    @Test("Update fails with non-existent feedback ID", .tags(.p1Core, .feedback, .integration))
    func updateNonExistentFails() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()
        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(nonExistentId)", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .notFound)
        })
    }

    @Test("Updated feedback persists correctly", .tags(.p1Core, .feedback, .integration))
    func updatePersistsCorrectly() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let feedback = FeedbackModel.mock(status: .pending)
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response async throws in
            #expect(response.status == .ok)

            // Verify persistence
            let updated = try await testWorld.feedbacks.find(id: feedbackId)
            #expect(updated?.status == .reviewed)
        })
    }

    // MARK: - P2 Extended Tests

    @Test("All valid status transitions work", .tags(.p2Extended, .feedback, .integration))
    func allStatusTransitionsWork() async throws {
        let transitions: [(from: FeedbackStatus, to: String)] = [
            (.pending, "reviewed"),
            (.reviewed, "resolved"),
            (.pending, "resolved"),
            (.resolved, "pending")
        ]

        for transition in transitions {
            await testWorld.resetAll()
            let admin = try await testWorld.dataFactory.createAdminUser()
            try await app.repositories.users.create(admin)

            let feedback = FeedbackModel.mock(status: transition.from)
            try await testWorld.feedbacks.create(feedback)
            let feedbackId = feedback.id!

            let request = Feedback.UpdateStatus.Request(status: transition.to)

            try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response in
                #expect(response.status == .ok)
                expectContent(Feedback.Detail.Response.self, response) { detail in
                    #expect(detail.status == transition.to)
                }
            })
        }
    }

    @Test("Response contains all expected fields", .tags(.p2Extended, .feedback, .integration))
    func responseContainsAllFields() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let rulesSummaryId = UUID()
        let feedback = FeedbackModel.mock(
            rulesSummaryId: rulesSummaryId,
            gameTitle: "Catan",
            feedbackType: .incorrect,
            description: "Missing rules",
            userContact: "user@test.com",
            status: .pending
        )
        try await testWorld.feedbacks.create(feedback)
        let feedbackId = feedback.id!

        let request = Feedback.UpdateStatus.Request(status: "reviewed")

        try await app.test(.PATCH, "\(adminPath)/\(feedbackId)", user: admin, content: request, afterResponse: { response in
            #expect(response.status == .ok)
            expectContent(Feedback.Detail.Response.self, response) { detail in
                #expect(detail.id == feedbackId)
                #expect(detail.rulesSummaryId == rulesSummaryId)
                #expect(detail.gameTitle == "Catan")
                #expect(detail.feedbackType == "incorrect")
                #expect(detail.description == "Missing rules")
                #expect(detail.userContact == "user@test.com")
                #expect(detail.status == "reviewed")
            }
        })
    }
}

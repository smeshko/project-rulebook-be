@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct FeedbackAdminListTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let adminPath = "api/v1/admin/feedback"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - P0 Critical Tests

    @Test("Admin can list all feedback", .tags(.p0Critical, .feedback, .integration))
    func listAllFeedback() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let feedback1 = FeedbackModel.mock(gameTitle: "Catan", feedbackType: .incorrect, status: .pending)
        let feedback2 = FeedbackModel.mock(gameTitle: "Root", feedbackType: .incomplete, status: .reviewed)
        let feedback3 = FeedbackModel.mock(gameTitle: "Wingspan", feedbackType: .other, status: .resolved)
        try await testWorld.feedbacks.create(feedback1)
        try await testWorld.feedbacks.create(feedback2)
        try await testWorld.feedbacks.create(feedback3)

        try await app.test(.GET, adminPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.items.count == 3)
                #expect(list.total == 3)
                #expect(list.page == 1)
                #expect(list.limit == 20)
            }
        }
    }

    @Test("List fails for unauthenticated request", .tags(.p0Critical, .feedback, .integration))
    func listUnauthenticatedFails() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, adminPath) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("List fails for non-admin user", .tags(.p0Critical, .feedback, .integration))
    func listNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        try await app.test(.GET, adminPath, user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    // MARK: - P1 Core Tests

    @Test("Admin can filter by status", .tags(.p1Core, .feedback, .integration))
    func filterByStatus() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let pending1 = FeedbackModel.mock(gameTitle: "Catan", status: .pending)
        let pending2 = FeedbackModel.mock(gameTitle: "Root", status: .pending)
        let reviewed = FeedbackModel.mock(gameTitle: "Wingspan", status: .reviewed)
        try await testWorld.feedbacks.create(pending1)
        try await testWorld.feedbacks.create(pending2)
        try await testWorld.feedbacks.create(reviewed)

        try await app.test(.GET, "\(adminPath)?status=pending", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.items.count == 2)
                #expect(list.total == 2)
                #expect(list.items.allSatisfy { $0.status == "pending" })
            }
        }
    }

    @Test("Pagination works correctly", .tags(.p1Core, .feedback, .integration))
    func paginationWorks() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        for i in 0..<5 {
            let model = FeedbackModel.mock(gameTitle: "Game \(i)", status: .pending)
            try await testWorld.feedbacks.create(model)
        }

        try await app.test(.GET, "\(adminPath)?page=1&limit=2", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.items.count == 2)
                #expect(list.total == 5)
                #expect(list.page == 1)
                #expect(list.limit == 2)
            }
        }
    }

    @Test("Second page returns correct items", .tags(.p1Core, .feedback, .integration))
    func secondPageCorrect() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        for i in 0..<5 {
            let model = FeedbackModel.mock(gameTitle: "Game \(i)", status: .pending)
            try await testWorld.feedbacks.create(model)
        }

        try await app.test(.GET, "\(adminPath)?page=2&limit=2", user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.items.count == 2)
                #expect(list.total == 5)
                #expect(list.page == 2)
                #expect(list.limit == 2)
            }
        }
    }

    @Test("Invalid status parameter returns 400", .tags(.p1Core, .feedback, .integration))
    func invalidStatusReturns400() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        try await app.test(.GET, "\(adminPath)?status=invalid", user: admin) { response in
            #expect(response.status == .badRequest)
        }
    }

    // MARK: - P2 Extended Tests

    @Test("Empty list returns empty items with total 0", .tags(.p2Extended, .feedback, .integration))
    func emptyListReturnsEmpty() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        try await app.test(.GET, adminPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.items.count == 0)
                #expect(list.total == 0)
            }
        }
    }

    @Test("Default pagination values work", .tags(.p2Extended, .feedback, .integration))
    func defaultPaginationValues() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        let model = FeedbackModel.mock(gameTitle: "Catan", status: .pending)
        try await testWorld.feedbacks.create(model)

        try await app.test(.GET, adminPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(Feedback.List.Response.self, response) { list in
                #expect(list.page == 1)
                #expect(list.limit == 20)
            }
        }
    }
}

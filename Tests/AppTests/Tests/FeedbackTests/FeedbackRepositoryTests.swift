@testable import App
import Fluent
import Foundation
import Testing
import Vapor

@Suite(.serialized)
struct FeedbackRepositoryTests {
    let world: IsolatedTestWorld
    let app: Application
    let repository: DatabaseFeedbackRepository

    init() async throws {
        world = try await IsolatedTestWorld()
        app = world.app
        repository = DatabaseFeedbackRepository(database: app.db)
        try await app.autoMigrate()
        try await cleanup()
    }

    // MARK: - Create and Find

    @Test("Feedback can be created and retrieved by ID", .tags(.p0Critical, .database, .unit))
    func createAndFindById() async throws {
        try await cleanup()
        let model = makeModel()
        try await repository.create(model)

        let found = try await repository.find(id: try model.requireID())
        #expect(found != nil)
        #expect(found?.gameTitle == "Catan")
        #expect(found?.feedbackType == .incorrect)
        #expect(found?.description == "The setup instructions are wrong")
        #expect(found?.status == .pending)
    }

    @Test("Create and find round-trip preserves all fields", .tags(.p0Critical, .database, .unit))
    func createAndFindRoundTrip() async throws {
        try await cleanup()
        let rulesSummaryId = UUID()
        let model = makeModel(
            rulesSummaryId: rulesSummaryId,
            gameTitle: "Root",
            feedbackType: .incomplete,
            description: "Missing faction rules",
            userContact: "user@test.com",
            status: .reviewed
        )
        try await repository.create(model)

        let found = try await repository.find(id: try model.requireID())
        #expect(found != nil)
        #expect(found?.rulesSummaryId == rulesSummaryId)
        #expect(found?.gameTitle == "Root")
        #expect(found?.feedbackType == .incomplete)
        #expect(found?.description == "Missing faction rules")
        #expect(found?.userContact == "user@test.com")
        #expect(found?.status == .reviewed)
        #expect(found?.createdAt != nil)
    }

    // MARK: - Find by Status

    @Test("findByStatus returns only matching records", .tags(.p0Critical, .database, .unit))
    func findByStatusFiltersCorrectly() async throws {
        try await cleanup()
        let pending1 = makeModel(gameTitle: "Game A", status: .pending)
        let pending2 = makeModel(gameTitle: "Game B", status: .pending)
        let reviewed = makeModel(gameTitle: "Game C", status: .reviewed)
        let resolved = makeModel(gameTitle: "Game D", status: .resolved)

        try await repository.create(pending1)
        try await repository.create(pending2)
        try await repository.create(reviewed)
        try await repository.create(resolved)

        let pendingResults = try await repository.findByStatus(.pending)
        #expect(pendingResults.count == 2)
        #expect(pendingResults.allSatisfy { $0.status == .pending })

        let reviewedResults = try await repository.findByStatus(.reviewed)
        #expect(reviewedResults.count == 1)
        #expect(reviewedResults.first?.gameTitle == "Game C")

        let resolvedResults = try await repository.findByStatus(.resolved)
        #expect(resolvedResults.count == 1)
        #expect(resolvedResults.first?.gameTitle == "Game D")
    }

    // MARK: - Pagination

    @Test("findPaginated returns correct page and total with status filter", .tags(.p1Core, .database, .unit))
    func findPaginatedWithStatusFilter() async throws {
        try await cleanup()
        // Create 5 pending and 2 reviewed
        for i in 1...5 {
            try await repository.create(makeModel(gameTitle: "Pending \(i)", status: .pending))
        }
        for i in 1...2 {
            try await repository.create(makeModel(gameTitle: "Reviewed \(i)", status: .reviewed))
        }

        // Page 1 of pending, limit 2
        let page1 = try await repository.findPaginated(status: .pending, page: 1, limit: 2)
        #expect(page1.total == 5)
        #expect(page1.items.count == 2)

        // Page 2 of pending, limit 2
        let page2 = try await repository.findPaginated(status: .pending, page: 2, limit: 2)
        #expect(page2.total == 5)
        #expect(page2.items.count == 2)

        // Page 3 of pending, limit 2 (only 1 remaining)
        let page3 = try await repository.findPaginated(status: .pending, page: 3, limit: 2)
        #expect(page3.total == 5)
        #expect(page3.items.count == 1)

        // All items without status filter
        let allPage = try await repository.findPaginated(status: nil, page: 1, limit: 10)
        #expect(allPage.total == 7)
        #expect(allPage.items.count == 7)
    }

    // MARK: - Count

    @Test("count returns correct counts with and without status filter", .tags(.p1Core, .database, .unit))
    func countWithStatusFilter() async throws {
        try await cleanup()
        try await repository.create(makeModel(status: .pending))
        try await repository.create(makeModel(status: .pending))
        try await repository.create(makeModel(status: .reviewed))

        let allCount = try await repository.count(status: nil)
        #expect(allCount == 3)

        let pendingCount = try await repository.count(status: .pending)
        #expect(pendingCount == 2)

        let reviewedCount = try await repository.count(status: .reviewed)
        #expect(reviewedCount == 1)

        let resolvedCount = try await repository.count(status: .resolved)
        #expect(resolvedCount == 0)
    }

    // MARK: - Migration

    @Test("Migration runs successfully and app boots without errors", .tags(.p0Critical, .database, .integration))
    func migrationRunsSuccessfully() async throws {
        // The fact that IsolatedTestWorld init succeeded with autoMigrate
        // proves the migration runs correctly on SQLite in-memory
        let count = try await repository.count(status: nil)
        #expect(count >= 0)
    }

    // MARK: - Helpers

    private func makeModel(
        rulesSummaryId: UUID? = UUID(),
        gameTitle: String = "Catan",
        feedbackType: FeedbackType = .incorrect,
        description: String = "The setup instructions are wrong",
        userContact: String? = nil,
        status: FeedbackStatus = .pending
    ) -> FeedbackModel {
        FeedbackModel(
            rulesSummaryId: rulesSummaryId,
            gameTitle: gameTitle,
            feedbackType: feedbackType,
            description: description,
            userContact: userContact,
            status: status
        )
    }

    @discardableResult
    private func cleanup() async throws {
        try await FeedbackModel.query(on: app.db).delete()
    }
}

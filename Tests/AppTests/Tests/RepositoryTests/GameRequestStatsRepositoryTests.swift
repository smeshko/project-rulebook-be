@testable import App
import Fluent
import Foundation
import Testing
import Vapor

@Suite(.serialized)
struct GameRequestStatsRepositoryTests {
    let world: IsolatedTestWorld
    let app: Application
    let repository: DatabaseGameRequestStatsRepository

    init() async throws {
        world = try await IsolatedTestWorld()
        app = world.app
        repository = DatabaseGameRequestStatsRepository(database: app.db)
        try await app.autoMigrate()
        try await cleanup()
    }

    @Test("Stats can be created via incrementCount for new game", .tags(.p0Critical, .database, .unit))
    func incrementCountCreatesNew() async throws {
        try await cleanup()
        try await repository.incrementCount(for: "catan")

        let stats = try await repository.find(bySanitizedTitle: "catan")
        #expect(stats != nil)
        #expect(stats?.requestCount == 1)
        #expect(stats?.lastRequestedAt != nil)
    }

    @Test("Stats increment count for existing game", .tags(.p0Critical, .database, .unit))
    func incrementCountUpdatesExisting() async throws {
        try await cleanup()
        try await repository.incrementCount(for: "catan")
        try await repository.incrementCount(for: "catan")
        try await repository.incrementCount(for: "catan")

        let stats = try await repository.find(bySanitizedTitle: "catan")
        #expect(stats?.requestCount == 3)
    }

    @Test("Top games returns ordered by request count descending", .tags(.p0Critical, .database, .unit))
    func topGamesOrdering() async throws {
        try await cleanup()

        // Create stats with different counts
        let low = GameRequestStats(sanitizedGameTitle: "low-game", requestCount: 5, lastRequestedAt: Date())
        let mid = GameRequestStats(sanitizedGameTitle: "mid-game", requestCount: 50, lastRequestedAt: Date())
        let high = GameRequestStats(sanitizedGameTitle: "high-game", requestCount: 100, lastRequestedAt: Date())
        try await low.create(on: app.db)
        try await mid.create(on: app.db)
        try await high.create(on: app.db)

        let topGames = try await repository.topGames(limit: 3)
        #expect(topGames.count == 3)
        #expect(topGames[0].sanitizedGameTitle == "high-game")
        #expect(topGames[1].sanitizedGameTitle == "mid-game")
        #expect(topGames[2].sanitizedGameTitle == "low-game")
    }

    @Test("Top games respects limit parameter", .tags(.p1Core, .database, .unit))
    func topGamesRespectsLimit() async throws {
        try await cleanup()

        for i in 1...10 {
            let stats = GameRequestStats(
                sanitizedGameTitle: "game-\(i)",
                requestCount: i * 10,
                lastRequestedAt: Date()
            )
            try await stats.create(on: app.db)
        }

        let topGames = try await repository.topGames(limit: 3)
        #expect(topGames.count == 3)
        #expect(topGames[0].requestCount == 100)
    }

    @Test("Find by sanitized title returns nil for non-existent game", .tags(.p1Core, .database, .unit))
    func findNonExistent() async throws {
        try await cleanup()
        let stats = try await repository.find(bySanitizedTitle: "nonexistent-game")
        #expect(stats == nil)
    }

    @Test("Unique constraint prevents duplicate sanitized titles", .tags(.p0Critical, .database, .unit))
    func uniqueConstraintEnforced() async throws {
        try await cleanup()
        let first = GameRequestStats(sanitizedGameTitle: "catan", requestCount: 1, lastRequestedAt: Date())
        try await first.create(on: app.db)

        let duplicate = GameRequestStats(sanitizedGameTitle: "catan", requestCount: 5, lastRequestedAt: Date())
        do {
            try await duplicate.create(on: app.db)
            Issue.record("Expected unique constraint violation")
        } catch {
            #expect(error.localizedDescription.contains("UNIQUE") || error.localizedDescription.contains("unique"))
        }
    }

    @discardableResult
    private func cleanup() async throws {
        try await GameRequestStats.query(on: app.db).delete()
    }
}

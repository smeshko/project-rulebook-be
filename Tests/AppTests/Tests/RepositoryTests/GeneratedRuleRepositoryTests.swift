@testable import App
import Fluent
import Foundation
import Testing
import Vapor

@Suite(.serialized)
struct GeneratedRuleRepositoryTests {
    let world: IsolatedTestWorld
    let app: Application
    let repository: DatabaseGeneratedRuleRepository

    init() async throws {
        world = try await IsolatedTestWorld()
        app = world.app
        repository = DatabaseGeneratedRuleRepository(database: app.db)
        try await app.autoMigrate()
        try await cleanup()
    }

    @Test("Generated rules can be created and retrieved by sanitized title")
    func createAndFindBySanitizedTitle() async throws {
        try await cleanup()
        let sanitizedTitle = try world.app.aiInputValidatorService
            .validateAndSanitizeGameTitle("Catan")
        let model = makeModel(
            originalTitle: "Catan",
            sanitizedTitle: sanitizedTitle,
            cacheKey: "rules:\(sanitizedTitle.lowercased())"
        )
        try await repository.create(model)

        let stored = try await repository.find(bySanitizedTitle: sanitizedTitle)
        #expect(stored != nil)
        #expect(stored?.title == "Settlers of Catan")
        #expect(stored?.resourcesVideoLinks == ["https://videos.example/catan"])
    }

    @Test("Touch updates last accessed timestamp")
    func touchUpdatesLastAccessedAt() async throws {
        try await cleanup()
        let sanitizedTitle = try world.app.aiInputValidatorService
            .validateAndSanitizeGameTitle("Root")
        let initialAccess = Date(timeIntervalSince1970: 0)
        let model = makeModel(
            originalTitle: "Root",
            sanitizedTitle: sanitizedTitle,
            cacheKey: "rules:\(sanitizedTitle.lowercased())",
            lastAccessed: initialAccess
        )
        try await repository.create(model)
        let identifier = try model.requireID()

        try await repository.touch(identifier)
        let updated = try await repository.find(bySanitizedTitle: sanitizedTitle)
        #expect(updated?.lastAccessedAt != nil)
        #expect((updated?.lastAccessedAt ?? initialAccess) > initialAccess)
    }

    @Test("Unique constraints prevent duplicate sanitized titles")
    func uniqueConstraintEnforced() async throws {
        try await cleanup()
        let sanitizedTitle = try world.app.aiInputValidatorService
            .validateAndSanitizeGameTitle("Azul")
        let first = makeModel(
            originalTitle: "Azul",
            sanitizedTitle: sanitizedTitle,
            cacheKey: "rules:\(sanitizedTitle.lowercased())"
        )
        try await repository.create(first)

        let duplicate = makeModel(
            originalTitle: "Azul Second",
            sanitizedTitle: sanitizedTitle,
            cacheKey: "rules:\(sanitizedTitle.lowercased())"
        )

        do {
            try await repository.create(duplicate)
            Issue.record("Expected unique constraint violation when creating duplicate generated rule")
        } catch {
            #expect(error.localizedDescription.contains("UNIQUE") || error.localizedDescription.contains("unique"))
        }
    }

    private func makeModel(
        originalTitle: String,
        sanitizedTitle: String,
        cacheKey: String,
        lastAccessed: Date = Date(timeIntervalSince1970: 0)
    ) -> GeneratedRuleModel {
        GeneratedRuleModel(
            originalTitle: originalTitle,
            sanitizedTitle: sanitizedTitle,
            cacheKey: cacheKey,
            title: "Settlers of Catan",
            playerCount: "3-4",
            playTime: "60-90 minutes",
            summary: "Trade resources and build settlements",
            initialSetup: ["Place the board", "Distribute resources"],
            firstRoundGuide: ["Roll dice", "Collect resources"],
            winCondition: "Reach 10 victory points",
            deepDive: ["Longest road strategy", "Development cards"],
            resourcesVideoLinks: ["https://videos.example/catan"],
            resourcesWebLinks: ["https://boardgamegeek.com/boardgame/13/catan"],
            confidence: 95,
            notes: "Validated against official rulebook",
            lastAccessedAt: lastAccessed
        )
    }

    @discardableResult
    private func cleanup() async throws {
        try await GeneratedRuleModel.query(on: app.db).delete()
    }
}

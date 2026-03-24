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

    @Test("Generated rules can be created and retrieved by sanitized title", .tags(.p0Critical, .database, .unit))
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

    @Test("Touch updates last accessed timestamp", .tags(.p1Core, .database, .unit))
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

    @Test("Unique constraints prevent duplicate sanitized titles", .tags(.p0Critical, .database, .unit))
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
            complexity: 2.3,
            recommendedAge: "10+",
            mechanics: ["Trading", "Route Building", "Dice Rolling"],
            summary: "Trade resources and build settlements",
            winCondition: "Reach 10 victory points",
            endGameTrigger: "A player reaches 10 victory points on their turn",
            scoringCategories: [
                RulesSummary.Response.ScoringCategory(name: "Settlements", value: "1 VP each"),
                RulesSummary.Response.ScoringCategory(name: "Cities", value: "2 VP each"),
            ],
            components: [
                RulesSummary.Response.Component(name: "Resource Cards", quantity: 95, category: .cards),
                RulesSummary.Response.Component(name: "Game Board", quantity: 1, category: .board),
            ],
            initialSetup: [
                RulesSummary.Response.SetupStep(step: 1, action: "Assemble the game board by arranging hex tiles"),
                RulesSummary.Response.SetupStep(step: 2, action: "Place number tokens on each resource hex"),
            ],
            turnStructure: RulesSummary.Response.TurnStructure(
                type: .sequential,
                actions: [
                    RulesSummary.Response.GameAction(id: "roll_dice", name: "Roll Dice", icon: "dice.fill", description: "Roll both dice to determine resource production"),
                    RulesSummary.Response.GameAction(id: "trade", name: "Trade", icon: "arrow.triangle.2.circlepath", description: "Trade resources with other players or the bank"),
                    RulesSummary.Response.GameAction(id: "build", name: "Build", icon: "hammer.fill", description: "Build roads, settlements, or cities"),
                ]
            ),
            firstRoundGuide: [
                RulesSummary.Response.GuideStep(step: 1, description: "Roll the dice and collect any resources"),
                RulesSummary.Response.GuideStep(step: 2, description: "Trade with other players if desired"),
            ],
            glossary: [
                RulesSummary.Response.GlossaryTerm(term: "Settlement", definition: "A building placed at an intersection worth 1 VP"),
            ],
            deepDive: ["Longest road strategy", "Development cards"],
            commonMistakes: [
                RulesSummary.Response.CommonMistake(rule: "Robber activation", mistake: "Forgetting to move the robber when a 7 is rolled", correct: "Always move the robber and steal when a 7 is rolled", severity: .gameBreaking),
            ],
            quickReference: RulesSummary.Response.QuickReference(
                turnSummary: ["Roll dice", "Collect resources", "Trade", "Build"],
                keyRules: ["Need 10 VP to win", "7 triggers robber"]
            ),
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

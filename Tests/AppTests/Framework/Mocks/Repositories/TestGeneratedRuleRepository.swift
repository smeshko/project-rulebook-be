@testable import App
import Foundation
import Vapor

actor TestGeneratedRuleRepository: GeneratedRuleRepository, TestRepository {
    private var rules: [GeneratedRuleModel]

    init(rules: [GeneratedRuleModel] = []) {
        self.rules = rules
    }

    typealias Model = GeneratedRuleModel

    func find(bySanitizedTitle sanitizedTitle: String) async throws -> GeneratedRuleModel? {
        rules.first { $0.sanitizedTitle == sanitizedTitle }
    }

    func create(_ model: GeneratedRuleModel) async throws {
        if rules.contains(where: { $0.sanitizedTitle == model.sanitizedTitle }) {
            throw Abort(.conflict, reason: "UNIQUE constraint failed: generated_rules.game_title_sanitized")
        }
        model.id = model.id ?? UUID()
        rules.append(model)
    }

    func update(_ model: GeneratedRuleModel) async throws {
        guard let identifier = model.id,
              let index = rules.firstIndex(where: { $0.id == identifier }) else {
            throw Abort(.notFound)
        }
        rules[index] = model
    }

    func touch(_ id: UUID) async throws {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        rules[index].lastAccessedAt = Date.now
    }

    func delete(id: UUID) async throws {
        rules.removeAll { $0.id == id }
    }

    func count() async throws -> Int {
        rules.count
    }

    func reset() async {
        rules.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestGeneratedRuleRepository {
        self
    }
}

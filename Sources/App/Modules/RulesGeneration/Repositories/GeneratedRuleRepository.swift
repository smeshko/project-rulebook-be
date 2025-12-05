import Fluent
import Foundation
import Vapor

protocol GeneratedRuleRepository: Repository {
    func find(bySanitizedTitle sanitizedTitle: String) async throws -> GeneratedRuleModel?
    func create(_ model: GeneratedRuleModel) async throws
    func update(_ model: GeneratedRuleModel) async throws
    func touch(_ id: UUID) async throws
}

struct DatabaseGeneratedRuleRepository: GeneratedRuleRepository, DatabaseRepository {
    typealias Model = GeneratedRuleModel

    let database: Database

    func find(bySanitizedTitle sanitizedTitle: String) async throws -> GeneratedRuleModel? {
        try await GeneratedRuleModel.query(on: database)
            .filter(\.$sanitizedTitle == sanitizedTitle)
            .first()
    }

    func create(_ model: GeneratedRuleModel) async throws {
        try await model.create(on: database)
    }

    func update(_ model: GeneratedRuleModel) async throws {
        try await model.update(on: database)
    }

    func touch(_ id: UUID) async throws {
        try await GeneratedRuleModel.query(on: database)
            .filter(\.$id == id)
            .set(\.$lastAccessedAt, to: Date())
            .update()
    }
}

extension Application.Repositories {
    var generatedRules: any GeneratedRuleRepository {
        application.generatedRuleRepository
    }
}

extension Request.Services {
    var generatedRules: any GeneratedRuleRepository {
        request.application.generatedRuleRepository
    }
}

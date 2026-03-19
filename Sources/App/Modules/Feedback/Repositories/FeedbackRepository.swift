import Fluent
import Vapor

protocol FeedbackRepository: Repository {
    func find(id: UUID) async throws -> FeedbackModel?
    func create(_ model: FeedbackModel) async throws
    func all() async throws -> [FeedbackModel]
    func findByStatus(_ status: FeedbackStatus) async throws -> [FeedbackModel]
    func findPaginated(status: FeedbackStatus?, page: Int, limit: Int) async throws -> (items: [FeedbackModel], total: Int)
    func update(_ model: FeedbackModel) async throws
    func count(status: FeedbackStatus?) async throws -> Int
}

struct DatabaseFeedbackRepository: FeedbackRepository, DatabaseRepository {
    typealias Model = FeedbackModel

    let database: Database

    func find(id: UUID) async throws -> FeedbackModel? {
        try await FeedbackModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func create(_ model: FeedbackModel) async throws {
        try await model.create(on: database)
    }

    func all() async throws -> [FeedbackModel] {
        try await FeedbackModel.query(on: database)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func findByStatus(_ status: FeedbackStatus) async throws -> [FeedbackModel] {
        try await FeedbackModel.query(on: database)
            .filter(\.$status == status)
            .sort(\.$createdAt, .descending)
            .all()
    }

    func findPaginated(status: FeedbackStatus?, page: Int, limit: Int) async throws -> (items: [FeedbackModel], total: Int) {
        var countQuery = FeedbackModel.query(on: database)
        if let status {
            countQuery = countQuery.filter(\.$status == status)
        }
        let total = try await countQuery.count()

        let offset = (page - 1) * limit
        var itemsQuery = FeedbackModel.query(on: database)
        if let status {
            itemsQuery = itemsQuery.filter(\.$status == status)
        }
        let items = try await itemsQuery
            .sort(\.$createdAt, .descending)
            .range(offset..<(offset + limit))
            .all()

        return (items: items, total: total)
    }

    func update(_ model: FeedbackModel) async throws {
        try await model.update(on: database)
    }

    func count(status: FeedbackStatus?) async throws -> Int {
        var query = FeedbackModel.query(on: database)
        if let status {
            query = query.filter(\.$status == status)
        }
        return try await query.count()
    }
}

extension Application.Repositories {
    var feedback: any FeedbackRepository {
        application.feedbackRepository
    }
}

extension Request.Services {
    var feedback: any FeedbackRepository {
        request.application.feedbackRepository
    }
}

import Fluent
import Vapor

protocol WaitlistRepository: Repository {
    func find(id: UUID) async throws -> WaitlistEntryModel?
    func find(email: String) async throws -> WaitlistEntryModel?
    func find(token: String) async throws -> WaitlistEntryModel?
    func create(_ model: WaitlistEntryModel) async throws
    func delete(_ model: WaitlistEntryModel) async throws
    func all() async throws -> [WaitlistEntryModel]
    func findUnnotified() async throws -> [WaitlistEntryModel]
    func update(_ model: WaitlistEntryModel) async throws
    func count() async throws -> Int
    func countNotified() async throws -> Int
}

struct DatabaseWaitlistRepository: WaitlistRepository, DatabaseRepository {
    typealias Model = WaitlistEntryModel
    let database: Database

    func find(id: UUID) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(email: String) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$email == email)
            .first()
    }

    func find(token: String) async throws -> WaitlistEntryModel? {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$unsubscribeToken == token)
            .first()
    }

    func create(_ model: WaitlistEntryModel) async throws {
        try await model.create(on: database)
    }

    func delete(_ model: WaitlistEntryModel) async throws {
        try await model.delete(on: database)
    }

    func all() async throws -> [WaitlistEntryModel] {
        try await WaitlistEntryModel.query(on: database).all()
    }

    func findUnnotified() async throws -> [WaitlistEntryModel] {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$notifiedAt == nil)
            .all()
    }

    func update(_ model: WaitlistEntryModel) async throws {
        try await model.update(on: database)
    }

    func count() async throws -> Int {
        try await WaitlistEntryModel.query(on: database).count()
    }

    func countNotified() async throws -> Int {
        try await WaitlistEntryModel.query(on: database)
            .filter(\.$notifiedAt != nil)
            .count()
    }
}

extension Application.Repositories {
    var waitlist: any WaitlistRepository {
        DatabaseWaitlistRepository(database: application.db)
    }
}

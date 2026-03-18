import Fluent
import Vapor

protocol ReceiptsRepository: Repository {
    func find(id: UUID) async throws -> TransactionModel?
    func find(transactionId: String) async throws -> TransactionModel?
    func create(_ model: TransactionModel) async throws
    func all() async throws -> [TransactionModel]
    func markRefunded(transactionId: String, refundedAt: Date) async throws
    func markRevoked(transactionId: String) async throws
}

struct DatabaseReceiptsRepository: ReceiptsRepository, DatabaseRepository {
    typealias Model = TransactionModel

    let database: Database

    func find(id: UUID) async throws -> TransactionModel? {
        try await TransactionModel.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find(transactionId: String) async throws -> TransactionModel? {
        try await TransactionModel.query(on: database)
            .filter(\.$transactionId == transactionId)
            .first()
    }

    func all() async throws -> [TransactionModel] {
        try await TransactionModel.query(on: database)
            .all()
    }

    func create(_ model: TransactionModel) async throws {
        try await model.create(on: database)
    }

    func markRefunded(transactionId: String, refundedAt: Date) async throws {
        guard let transaction = try await find(transactionId: transactionId) else {
            return
        }
        transaction.status = .refunded
        transaction.refundedAt = refundedAt
        try await transaction.save(on: database)
    }

    func markRevoked(transactionId: String) async throws {
        guard let transaction = try await find(transactionId: transactionId) else {
            return
        }
        transaction.status = .revoked
        try await transaction.save(on: database)
    }
}

extension Application.Repositories {
    var receipts: any ReceiptsRepository {
        application.receiptsRepository
    }
}

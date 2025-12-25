import Fluent
import Vapor

/// Protocol defining receipt storage and retrieval operations.
///
/// Implementations of this protocol handle persistence of validated purchase
/// receipts for duplicate detection, historical tracking, and subscription management.
protocol ReceiptRepository: Sendable {
    /// Creates a new receipt record in the database.
    ///
    /// - Parameter receipt: The receipt model to persist.
    /// - Throws: Database errors or constraint violations.
    func create(_ receipt: ReceiptModel) async throws

    /// Finds a receipt by its platform-specific transaction ID.
    ///
    /// - Parameters:
    ///   - transactionId: The platform transaction ID.
    ///   - platform: The platform (iOS or Android).
    /// - Returns: The receipt if found, nil otherwise.
    func find(transactionId: String, platform: PurchasePlatform) async throws -> ReceiptModel?

    /// Checks if a transaction has already been processed.
    ///
    /// - Parameters:
    ///   - transactionId: The platform transaction ID.
    ///   - platform: The platform (iOS or Android).
    /// - Returns: `true` if the transaction exists in the database.
    func exists(transactionId: String, platform: PurchasePlatform) async throws -> Bool

    /// Finds all receipts for a specific user.
    ///
    /// - Parameter userId: The user's ID.
    /// - Returns: Array of receipt models for the user.
    func findByUser(userId: UUID) async throws -> [ReceiptModel]

    /// Finds all active purchases for a specific user.
    ///
    /// - Parameter userId: The user's ID.
    /// - Returns: Array of active receipt models.
    func findActiveByUser(userId: UUID) async throws -> [ReceiptModel]

    /// Finds a receipt by its database ID.
    ///
    /// - Parameter id: The receipt's UUID.
    /// - Returns: The receipt if found, nil otherwise.
    func find(id: UUID) async throws -> ReceiptModel?

    /// Updates an existing receipt record.
    ///
    /// - Parameter receipt: The receipt model with updated values.
    /// - Throws: Database errors.
    func update(_ receipt: ReceiptModel) async throws

    /// Updates the status of a receipt.
    ///
    /// - Parameters:
    ///   - transactionId: The transaction ID to update.
    ///   - platform: The platform.
    ///   - status: The new status.
    /// - Throws: Database errors.
    func updateStatus(transactionId: String, platform: PurchasePlatform, status: PurchaseStatus) async throws
}

/// Database-backed implementation of ReceiptRepository.
struct DatabaseReceiptRepository: ReceiptRepository {
    let database: Database

    init(database: Database) {
        self.database = database
    }

    func create(_ receipt: ReceiptModel) async throws {
        try await receipt.create(on: database)
    }

    func find(transactionId: String, platform: PurchasePlatform) async throws -> ReceiptModel? {
        try await ReceiptModel.query(on: database)
            .filter(\.$transactionId == transactionId)
            .filter(\.$platform == platform)
            .first()
    }

    func exists(transactionId: String, platform: PurchasePlatform) async throws -> Bool {
        let count = try await ReceiptModel.query(on: database)
            .filter(\.$transactionId == transactionId)
            .filter(\.$platform == platform)
            .count()
        return count > 0
    }

    func findByUser(userId: UUID) async throws -> [ReceiptModel] {
        try await ReceiptModel.query(on: database)
            .filter(\.$userId == userId)
            .sort(\.$purchaseDate, .descending)
            .all()
    }

    func findActiveByUser(userId: UUID) async throws -> [ReceiptModel] {
        try await ReceiptModel.query(on: database)
            .filter(\.$userId == userId)
            .filter(\.$status == .active)
            .sort(\.$purchaseDate, .descending)
            .all()
    }

    func find(id: UUID) async throws -> ReceiptModel? {
        try await ReceiptModel.find(id, on: database)
    }

    func update(_ receipt: ReceiptModel) async throws {
        try await receipt.update(on: database)
    }

    func updateStatus(transactionId: String, platform: PurchasePlatform, status: PurchaseStatus) async throws {
        guard let receipt = try await find(transactionId: transactionId, platform: platform) else {
            return
        }
        receipt.status = status
        try await receipt.update(on: database)
    }
}

// MARK: - Application Extension

extension Application.Repositories {
    var receipts: any ReceiptRepository {
        DatabaseReceiptRepository(database: application.db)
    }
}

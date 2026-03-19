import Vapor

final class PendingValidationJob: @unchecked Sendable {

    private let app: Application
    private var task: Task<Void, Never>?

    /// Backoff intervals in seconds for each retry attempt.
    static let backoffIntervals: [TimeInterval] = [300, 1200, 3600] // 5min, 20min, 60min
    static let maxRetries = 3
    static let jobInterval: UInt64 = 300 // 5 minutes

    init(app: Application) {
        self.app = app
    }

    func start() {
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.jobInterval))
                } catch {
                    break
                }
                await self.processPendingValidations()
            }
        }
    }

    func shutdown() {
        task?.cancel()
        task = nil
    }

    // MARK: - Private

    private func processPendingValidations() async {
        do {
            let repository = DatabaseReceiptsRepository(database: app.db)
            let pending = try await repository.findPendingValidations()

            for transaction in pending {
                guard !Task.isCancelled else { break }
                await processTransaction(transaction, repository: repository)
            }
        } catch {
            app.logger.error("PendingValidationJob: Failed to fetch pending validations", metadata: [
                "error": .string(String(describing: error))
            ])
        }
    }

    private func processTransaction(_ transaction: TransactionModel, repository: DatabaseReceiptsRepository) async {
        guard let transactionId = transaction.id else { return }

        // Check if eligible for retry based on backoff schedule
        guard isEligibleForRetry(transaction) else { return }

        guard let receiptData = transaction.receiptData else {
            app.logger.error("PendingValidationJob: Missing receiptData for pending transaction", metadata: [
                "transactionId": .string(transaction.transactionId)
            ])
            // Mark as failed since we can't retry without receipt data
            do {
                try await repository.updateStatus(
                    id: transactionId,
                    status: .validationFailed,
                    retryCount: nil,
                    lastRetryAt: nil
                )
                app.logger.critical("Pending validation failed: missing receipt data", metadata: [
                    "transactionId": .string(transaction.transactionId)
                ])
            } catch {
                app.logger.error("PendingValidationJob: Failed to update status", metadata: [
                    "error": .string(String(describing: error))
                ])
            }
            return
        }

        do {
            let result: (transactionId: String, isValid: Bool)

            switch transaction.platform {
            case .ios:
                let validationResult = try await app.appStoreValidationService.verify(signedTransaction: receiptData)
                result = (validationResult.transactionId, validationResult.productId == transaction.productId)

            case .android:
                let validationResult = try await app.playStoreValidationService.verify(
                    productId: transaction.productId,
                    purchaseToken: receiptData
                )
                result = (validationResult.transactionId, validationResult.productId == transaction.productId)
            }

            let originalId = transaction.transactionId

            // Check for duplicate with the real transaction ID
            if let existing = try await repository.find(transactionId: result.transactionId),
               existing.id != transactionId {
                // Another transaction with the real ID already exists — clean up this pending record
                transaction.status = .valid
                transaction.receiptData = nil
                try await transaction.save(on: app.db)
            } else {
                // Update with real transaction ID and final status
                let finalStatus: TransactionStatus = result.isValid ? .valid : .validationFailed
                transaction.transactionId = result.transactionId
                transaction.status = finalStatus
                transaction.receiptData = nil
                transaction.lastRetryAt = Date()
                try await transaction.save(on: app.db)
            }

            app.logger.info("PendingValidationJob: Successfully validated pending transaction", metadata: [
                "originalId": .string(originalId),
                "realTransactionId": .string(result.transactionId),
                "status": .string(result.isValid ? "valid" : "invalid")
            ])

        } catch let validationError as AppStoreValidationError where Self.isDefinitiveAppStoreError(validationError) {
            // Definitive validation failure — no point retrying
            do {
                try await repository.updateStatus(
                    id: transactionId,
                    status: .validationFailed,
                    retryCount: transaction.retryCount,
                    lastRetryAt: Date()
                )
                app.logger.critical("Pending validation definitively failed", metadata: [
                    "transactionId": .string(transaction.transactionId),
                    "platform": .string(transaction.platform.rawValue),
                    "error": .string(String(describing: validationError))
                ])
            } catch {
                app.logger.error("PendingValidationJob: Failed to mark as validation_failed", metadata: [
                    "error": .string(String(describing: error))
                ])
            }
        } catch let validationError as PlayStoreValidationError where Self.isDefinitivePlayStoreError(validationError) {
            // Definitive validation failure — no point retrying
            do {
                try await repository.updateStatus(
                    id: transactionId,
                    status: .validationFailed,
                    retryCount: transaction.retryCount,
                    lastRetryAt: Date()
                )
                app.logger.critical("Pending validation definitively failed", metadata: [
                    "transactionId": .string(transaction.transactionId),
                    "platform": .string(transaction.platform.rawValue),
                    "error": .string(String(describing: validationError))
                ])
            } catch {
                app.logger.error("PendingValidationJob: Failed to mark as validation_failed", metadata: [
                    "error": .string(String(describing: error))
                ])
            }
        } catch {
            // Transient error — increment retry count
            let newRetryCount = transaction.retryCount + 1

            if newRetryCount >= Self.maxRetries {
                // Exhausted all retries
                do {
                    try await repository.updateStatus(
                        id: transactionId,
                        status: .validationFailed,
                        retryCount: newRetryCount,
                        lastRetryAt: Date()
                    )
                    app.logger.critical("Pending validation exhausted all retries", metadata: [
                        "transactionId": .string(transaction.transactionId),
                        "platform": .string(transaction.platform.rawValue),
                        "retryCount": .string("\(newRetryCount)")
                    ])
                } catch {
                    app.logger.error("PendingValidationJob: Failed to mark as validation_failed", metadata: [
                        "error": .string(String(describing: error))
                    ])
                }
            } else {
                // Still has retries left
                do {
                    try await repository.updateStatus(
                        id: transactionId,
                        status: .pendingValidation,
                        retryCount: newRetryCount,
                        lastRetryAt: Date()
                    )
                    app.logger.warning("PendingValidationJob: Retry failed, will retry later", metadata: [
                        "transactionId": .string(transaction.transactionId),
                        "retryCount": .string("\(newRetryCount)"),
                        "error": .string(String(describing: error))
                    ])
                } catch {
                    app.logger.error("PendingValidationJob: Failed to update retry count", metadata: [
                        "error": .string(String(describing: error))
                    ])
                }
            }
        }
    }

    private func isEligibleForRetry(_ transaction: TransactionModel) -> Bool {
        let retryCount = transaction.retryCount

        // Already exhausted retries
        guard retryCount < Self.maxRetries else { return false }

        // First attempt (never retried before)
        guard let lastRetryAt = transaction.lastRetryAt else { return true }

        // Check if enough time has elapsed based on backoff schedule
        let backoffIndex = min(retryCount, Self.backoffIntervals.count - 1)
        let requiredInterval = Self.backoffIntervals[backoffIndex]
        let elapsed = Date().timeIntervalSince(lastRetryAt)

        return elapsed >= requiredInterval
    }

    /// Returns true for App Store errors that indicate a definitively invalid receipt (not transient).
    private static func isDefinitiveAppStoreError(_ error: AppStoreValidationError) -> Bool {
        switch error {
        case .invalidSignature, .invalidCertificateChain, .bundleIdMismatch, .verificationFailed:
            return true
        case .configurationError:
            return true
        }
    }

    /// Returns true for Play Store errors that indicate a definitively invalid receipt (not transient).
    private static func isDefinitivePlayStoreError(_ error: PlayStoreValidationError) -> Bool {
        switch error {
        case .invalidToken, .purchaseNotFound, .verificationFailed:
            return true
        case .configurationError:
            return true
        case .apiError(let code, _):
            return code < 500
        }
    }
}

@preconcurrency import AppStoreServerLibrary
import Vapor

struct AppleNotificationsController {

    struct AppleNotificationPayload: Content {
        let signedPayload: String
    }

    func handleNotification(_ req: Request) async throws -> HTTPStatus {
        do {
            let payload = try req.content.decode(AppleNotificationPayload.self)

            let result = try await req.services.appleNotification.verifyAndDecode(
                signedPayload: payload.signedPayload
            )

            switch result.notificationType {
            case .refund:
                guard let originalTransactionId = result.originalTransactionId else {
                    req.logger.warning("REFUND notification missing originalTransactionId")
                    return .ok
                }
                try await req.repositories.receipts.markRefunded(
                    transactionId: originalTransactionId,
                    refundedAt: Date()
                )
                req.logger.info("Processed REFUND notification", metadata: [
                    "originalTransactionId": .string(originalTransactionId)
                ])

            case .revoke:
                guard let originalTransactionId = result.originalTransactionId else {
                    req.logger.warning("REVOKE notification missing originalTransactionId")
                    return .ok
                }
                try await req.repositories.receipts.markRevoked(
                    transactionId: originalTransactionId
                )
                req.logger.info("Processed REVOKE notification", metadata: [
                    "originalTransactionId": .string(originalTransactionId)
                ])

            default:
                req.logger.info("Received Apple notification", metadata: [
                    "notificationType": .string(result.rawNotificationType ?? "unknown"),
                    "subtype": .string(result.subtype ?? "none")
                ])
            }
        } catch {
            req.logger.error("Failed to process Apple notification", metadata: [
                "error": .string(String(describing: error))
            ])
        }

        return .ok
    }
}

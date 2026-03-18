import Vapor

struct GoogleNotificationsController {

    func handleNotification(_ req: Request) async throws -> HTTPStatus {
        // Verify Pub/Sub push subscription token
        let config: GooglePlayConfig
        do {
            config = try req.application.configuration.google
        } catch {
            req.logger.error("Failed to load Google configuration", metadata: [
                "error": .string(String(describing: error))
            ])
            return .ok
        }

        guard let token = req.query[String.self, at: "token"],
              token == config.pubsubVerificationToken else {
            req.logger.warning("Google notification rejected: invalid or missing verification token")
            return .forbidden
        }

        do {
            let pushMessage = try req.content.decode(PubSubPushMessage.self)

            let result = try req.services.googleNotification.decodeNotification(
                base64Message: pushMessage.message.data
            )

            switch result.notificationType {
            case .oneTimeProductCanceled, .oneTimeProductRefunded:
                guard let purchaseToken = result.purchaseToken else {
                    req.logger.warning("Voided purchase notification missing purchaseToken", metadata: [
                        "notificationType": .string(String(describing: result.notificationType))
                    ])
                    return .ok
                }

                // Verify via Voided Purchases API to get the order ID (transaction ID)
                let orderId: String?
                do {
                    orderId = try await req.services.googleNotification.verifyVoidedPurchase(
                        purchaseToken: purchaseToken
                    )
                } catch {
                    req.logger.error("Failed to verify voided purchase", metadata: [
                        "purchaseToken": .string(String(purchaseToken.prefix(20)) + "..."),
                        "error": .string(String(describing: error))
                    ])
                    return .ok
                }

                guard let transactionId = orderId else {
                    req.logger.warning("Voided purchase not found in Voided Purchases API", metadata: [
                        "purchaseToken": .string(String(purchaseToken.prefix(20)) + "...")
                    ])
                    return .ok
                }

                let refundUpdated = try await req.repositories.receipts.markRefunded(
                    transactionId: transactionId,
                    refundedAt: Date()
                )
                if refundUpdated {
                    req.logger.info("Processed Google voided purchase notification", metadata: [
                        "transactionId": .string(transactionId),
                        "notificationType": .string(String(describing: result.notificationType)),
                        "productId": .string(result.productId ?? "unknown")
                    ])
                } else {
                    req.logger.warning("Google voided purchase for unknown transaction", metadata: [
                        "transactionId": .string(transactionId)
                    ])
                }

            default:
                req.logger.info("Received Google notification", metadata: [
                    "notificationType": .string(String(describing: result.notificationType)),
                    "packageName": .string(result.packageName ?? "unknown")
                ])
            }
        } catch {
            req.logger.error("Failed to process Google notification", metadata: [
                "error": .string(String(describing: error))
            ])
        }

        return .ok
    }
}

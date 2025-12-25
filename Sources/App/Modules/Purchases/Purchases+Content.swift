import Vapor

/// Namespace for Purchases-related request/response types.
enum Purchases {

    // MARK: - Validate

    /// Request/response types for purchase validation.
    enum Validate {
        /// Request body for validating a purchase receipt.
        struct Request: Content {
            /// Platform the purchase came from.
            let platform: PurchasePlatform

            /// Platform-specific receipt data.
            /// - iOS: The signedTransactionInfo JWS string from StoreKit 2
            /// - Android: The purchase token from Google Play Billing
            let receiptData: String

            /// Product identifier (required for Android).
            let productId: String?
        }

        /// Response from purchase validation.
        struct Response: Content {
            /// Whether validation was successful.
            let success: Bool

            /// The platform transaction ID.
            let transactionId: String

            /// The product that was purchased.
            let productId: String

            /// Current status of the purchase.
            let status: String

            /// Whether this transaction was previously validated.
            let isDuplicate: Bool
        }
    }

    // MARK: - List

    /// Request/response types for listing purchases.
    enum List {
        /// Response containing user's purchase history.
        struct Response: Content {
            /// Array of purchases.
            let purchases: [PurchaseItem]
        }

        /// Individual purchase item in the list.
        struct PurchaseItem: Content {
            /// Database ID of the receipt.
            let id: UUID

            /// Platform transaction ID.
            let transactionId: String

            /// Product identifier.
            let productId: String

            /// Platform (iOS/Android).
            let platform: PurchasePlatform

            /// When the purchase was made.
            let purchaseDate: Date

            /// When the subscription expires (nil for consumables).
            let expirationDate: Date?

            /// Current status.
            let status: PurchaseStatus
        }
    }

    // MARK: - Active

    /// Request/response types for checking active entitlements.
    enum Active {
        /// Response containing active entitlement information.
        struct Response: Content {
            /// Whether the user has any active subscriptions.
            let hasActiveSubscription: Bool

            /// Product IDs of active purchases.
            let productIds: [String]
        }
    }
}

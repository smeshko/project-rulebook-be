import Foundation
import Vapor

public enum Receipts {}

public extension Receipts {
    enum Validate {
        public struct Request: Codable, Equatable, Sendable {
            public let platform: String
            public let receiptData: String?
            public let purchaseToken: String?
            public let productId: String
            public let packageName: String?

            public init(
                platform: String,
                receiptData: String? = nil,
                purchaseToken: String? = nil,
                productId: String,
                packageName: String? = nil
            ) {
                self.platform = platform
                self.receiptData = receiptData
                self.purchaseToken = purchaseToken
                self.productId = productId
                self.packageName = packageName
            }
        }

        public struct Response: Codable, Equatable, Sendable {
            public let success: Bool
            public let status: String
            public let transactionId: String?
            public let error: String?

            public init(
                success: Bool,
                status: String,
                transactionId: String? = nil,
                error: String? = nil
            ) {
                self.success = success
                self.status = status
                self.transactionId = transactionId
                self.error = error
            }
        }
    }
}

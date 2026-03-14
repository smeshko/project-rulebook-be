import Vapor

// MARK: - Content Conformance

extension Receipts.Validate.Request: Content {}
extension Receipts.Validate.Response: Content {}

// MARK: - Product-to-Credits Mapping

extension Receipts {
    static let productCreditAmounts: [String: Int] = [
        "credits_1": 1,
        "credits_3": 3,
        "credits_10": 10,
    ]

    static func creditAmount(for productId: String) -> Int? {
        productCreditAmounts[productId]
    }
}

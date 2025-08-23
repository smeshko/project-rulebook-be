@testable import App
import Vapor

extension UserAccountModel {
    static func mock(
        app: Application,
        id: UUID = .init(),
        email: String = "test-\(UUID().uuidString.lowercased())@test.com",
        firstName: String? = "John",
        lastName: String? = "Doe",
        isAdmin: Bool = false,
        isEmailVerified: Bool = true
    ) throws -> UserAccountModel {
        UserAccountModel(
            id: id,
            email: email,
            password: "password", // Use plaintext password since TestWorld configures plaintext hasher
            firstName: firstName,
            lastName: lastName,
            isAdmin: isAdmin,
            isEmailVerified: isEmailVerified
        )
    }
}

@testable import App
import Fluent
import FluentSQLiteDriver
import XCTVapor

class TestWorld: @unchecked Sendable {
    let app: Application
    
    // Repositories
    private let tokenRepository: TestRefreshTokenRepository = .init()
    private let userRepository: TestUserRepository = .init()
    private let emailTokenRepository: TestEmailTokenRepository = .init()
    private let passwordTokenRepository: TestPasswordTokenRepository = .init()
    
    init(app: Application) throws {
        self.app = app
        
        try app.jwt.signers.use(.es256(key: .generate()))
        
        app.repositories.refreshTokensService.use { _ in self.tokenRepository }
        app.repositories.usersService.use { _ in self.userRepository }
        app.repositories.emailTokensService.use { _ in self.emailTokenRepository }
        app.repositories.passwordTokensService.use { _ in self.passwordTokenRepository }
        
        app.services.email.use(.fake)
    }
}

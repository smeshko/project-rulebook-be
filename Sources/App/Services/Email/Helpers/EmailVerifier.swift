import Vapor

struct EmailVerifier {
    let emailTokenRepository: any EmailTokenRepository
    let generator: RandomGeneratorService
    let application: Application
    
    func verify(for user: UserAccountModel) async throws {
        let token = generator.generate(bits: 256)
        let emailToken = try EmailTokenModel(userID: user.requireID(), value: SHA256.hash(token))
        try await emailTokenRepository.create(emailToken)
        
        let name = {
            if user.firstName == nil && user.lastName == nil {
                return "User"
            }
            return "\(user.firstName ?? "") \(user.lastName ?? "")"
        }()
        
        let content = BrevoMail(
            sender: .init(
                name: "Sender",
                email: "noreply@sender.com"
            ),
            to: [.init(
                name: name,
                email: user.email
            )],
            subject: "Verify your account",
            htmlContent: Templates.verifyEmail(token: emailToken.value, baseURL: try application.configuration.security.baseURL)
        )
        
        try await application.serviceCache.emailService.send(content)
    }
}

extension Application {
    var emailVerifier: EmailVerifier {
        .init(
            emailTokenRepository: repositories.emailTokens,
            generator: serviceCache.randomGeneratorService,
            application: self
        )
    }
}

extension Request {
    var emailVerifier: EmailVerifier {
        .init(
            emailTokenRepository: repositories.emailTokens,
            generator: services.randomGenerator,
            application: application
        )
    }
}


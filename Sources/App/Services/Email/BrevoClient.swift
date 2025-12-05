import Vapor

extension Application.Service.Provider where ServiceType == EmailService {
    static var brevo: Self {
        .init {
            $0.services.email.use { BrevoClient(app: $0) }
        }
    }
}

struct BrevoClient: EmailService {
    let app: Application
    
    func `for`(_ request: Request) -> any EmailService {
        Self.init(app: request.application)
    }
    
    @discardableResult
    func send(_ email: any Email) async throws -> HTTPStatus {
        let config = try app.configuration.services
        let response = try await app.client.post(
            URI(string: config.brevoURL),
            headers: .init([
                ("accept", "application/json"),
                ("api-key", config.brevoAPIKey),
                ("content-type", "application/json")
            ]),
            content: email
        )
        
        return response.status
    }
}


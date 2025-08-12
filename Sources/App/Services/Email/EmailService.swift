import Vapor

protocol EmailService {
    @discardableResult
    func send(_ email: any Email) async throws -> HTTPStatus
    
    func `for`(_ request: Request) -> EmailService
}

extension Application.Services {
    var email: Application.Service<EmailService> {
        .init(application: application)
    }
}

extension Request.Services {
    var email: EmailService {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.emailService.for(request)
    }
}

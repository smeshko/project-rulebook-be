import Vapor
import Foundation

protocol UUIDGeneratorService {
    func generate() -> UUID
    
    func `for`(_ request: Request) -> UUIDGeneratorService
}

extension Application.Services {
    var uuidGenerator: Application.Service<UUIDGeneratorService> {
        .init(application: application)
    }
}

extension Request.Services {
    var uuidGenerator: UUIDGeneratorService {
        self.request.application.services.uuidGenerator.service.for(request)
    }
}
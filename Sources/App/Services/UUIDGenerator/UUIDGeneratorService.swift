import Vapor
import Foundation

public protocol UUIDGeneratorService: Sendable {
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
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.uuidGeneratorService.for(request)
    }
}
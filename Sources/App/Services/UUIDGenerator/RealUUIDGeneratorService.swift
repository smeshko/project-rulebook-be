import Vapor
import Foundation

extension Application.Service.Provider where ServiceType == UUIDGeneratorService {
    static var random: Self {
        .init {
            $0.services.uuidGenerator.use { RealUUIDGeneratorService(app: $0) }
        }
    }
}

struct RealUUIDGeneratorService: UUIDGeneratorService {
    let app: Application
    
    func generate() -> UUID {
        UUID()
    }
    
    func `for`(_ request: Request) -> UUIDGeneratorService {
        Self(app: request.application)
    }
}
@testable import App
import Vapor

extension Application.Service.Provider where ServiceType == RandomGeneratorService {
    static func rigged(value: String) -> Self {
        .init {
            $0.services.randomGenerator.use { RiggedRandomGeneratorService(app: $0, value: value) }
        }
    }
}

struct RiggedRandomGeneratorService: RandomGeneratorService {
    let app: Application
    let value: String
    
    func generate(bits: Int) -> String {
        value
    }
    
    func `for`(_ request: Request) -> RandomGeneratorService {
        Self(app: request.application, value: value)
    }
}
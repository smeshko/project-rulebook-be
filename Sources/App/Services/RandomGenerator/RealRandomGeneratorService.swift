import Vapor

extension Application.Service.Provider where ServiceType == RandomGeneratorService {
    static var random: Self {
        .init {
            $0.services.randomGenerator.use { RealRandomGeneratorService(app: $0) }
        }
    }
}

struct RealRandomGeneratorService: RandomGeneratorService {
    let app: Application
    
    func generate(bits: Int) -> String {
        [UInt8].random(count: bits / 8).hex
    }
    
    func `for`(_ request: Request) -> RandomGeneratorService {
        Self(app: request.application)
    }
}
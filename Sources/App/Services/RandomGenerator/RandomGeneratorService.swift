import Vapor

protocol RandomGeneratorService {
    func generate(bits: Int) -> String
    
    func `for`(_ request: Request) -> RandomGeneratorService
}

extension Application.Services {
    var randomGenerator: Application.Service<RandomGeneratorService> {
        .init(application: application)
    }
}

extension Request.Services {
    var randomGenerator: RandomGeneratorService {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.randomGeneratorService.for(request)
    }
}
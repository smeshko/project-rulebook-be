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
        self.request.application.services.randomGenerator.service.for(request)
    }
}
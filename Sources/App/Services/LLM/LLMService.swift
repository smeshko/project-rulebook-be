import Vapor

protocol LLMService {
    func generate(input: String) async throws -> String
    
    func generateOptimized(
        input: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        useJSONMode: Bool
    ) async throws -> String

    func `for`(_ request: Request) -> LLMService
}

extension Application.Services {
    var llm: Application.Service<LLMService> {
        .init(application: application)
    }
}

extension Request.Services {
    var llm: LLMService {
        self.request.application.services.llm.service.for(request)
    }
}

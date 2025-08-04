import Vapor

extension Application.Service.Provider where ServiceType == LLMService {
    static var openAI: Self {
        .init {
            $0.services.llm.use { OpenAIService(app: $0) }
        }
    }
}

struct OpenAIService: LLMService {
    let app: Application
    
    private let headers: HTTPHeaders = [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(Environment.openAIKey)",
    ]
    
    func generate(input: [OpenAIRequest.Message]) async throws -> String {
        let response = try await app.client.post(
            .init(string: "https://api.openai.com/v1/responses"),
            headers: headers,
            content: OpenAIRequest(
                model: "gpt-4.1",
                input: input
            )
        )
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let decodedResponse = try response.content.decode(OpenAIResponse.self, using: decoder)
        guard let text = decodedResponse.output.first?.content.first?.text else {
            throw ContentError.externalServiceFailedToRespond
        }
        return text
    }
    
    func `for`(_ request: Request) -> LLMService {
        Self(app: request.application)
    }
}

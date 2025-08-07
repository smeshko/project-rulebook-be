import Vapor

struct OpenAIResponse: Content {
    struct Choice: Content {
        struct Message: Content {
            let role: String
            let content: String
        }
        
        let index: Int
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Usage: Content {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
    
    struct Error: Content {
        let message: String
        let type: String
        let param: String?
        let code: String?
    }
    
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    let error: Error?
}
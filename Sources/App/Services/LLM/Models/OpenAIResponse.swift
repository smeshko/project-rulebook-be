import Vapor

struct OpenAIResponse: Content {
    struct OutputItem: Content {
        struct OutputContent: Content {
            let type: String
            let text: String?
            
            enum CodingKeys: String, CodingKey {
                case type
                case text
            }
        }
        
        let id: String
        let type: String
        let status: String
        let role: String?
        let content: [OutputContent]
        
        enum CodingKeys: String, CodingKey {
            case id
            case type
            case status
            case role
            case content
        }
    }
    
    struct Usage: Content {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        
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
    let createdAt: Int
    let status: String
    let model: String?
    let output: [OutputItem]
    let usage: Usage?
    let error: Error?
    let incompleteDetails: String?
    let instructions: String?
    let maxOutputTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case object
        case createdAt = "created_at"
        case status
        case model
        case output
        case usage
        case error
        case incompleteDetails = "incomplete_details"
        case instructions
        case maxOutputTokens = "max_output_tokens"
    }
    
    // Extract text from the response
    func extractText() -> String? {
        return output.first(where: { $0.type == "message" })?
            .content.first(where: { $0.type == "output_text" })?
            .text
    }
}
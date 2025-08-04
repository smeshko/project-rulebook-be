import Vapor

struct OpenAIResponse: Content {
    enum Status: String, Content {
        case completed
        case failed
        case inProgress
        case cancelled
        case queued
        case incomplete
    }

    struct OutputMessage: Content {
        struct OutputContent: Content {
            let text: String
        }
        let id: String
        let status: Status
        let content: [OutputContent]
    }

    struct Usage: Content {
        struct InputTokensDetails: Content {
            let cachedTokens: Int
        }

        struct OutputTokensDetails: Content {
            let reasoningTokens: Int
        }
        let inputTokens: Int
        let inputTokensDetails: InputTokensDetails
        let outputTokens: Int
        let outputTokensDetails: OutputTokensDetails
        let totalTokens: Int
    }

    let id: String
    let object: String
    let createdAt: Int
    let status: Status
    let error: String?
    let model: String
    let output: [OutputMessage]
    let temperature: Double
    let usage: Usage
}

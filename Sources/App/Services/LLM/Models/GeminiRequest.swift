import Vapor

/// Request model for Google Gemini generateContent API.
///
/// Matches the expected structure for text and image generation requests:
/// - Text-only: a single part with `text`
/// - Image+Text: two parts where first is `inline_data` and second is `text`
struct GeminiRequest: Content {
    struct ContentItem: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String?
        let inlineData: InlineData?

        enum CodingKeys: String, CodingKey {
            case text
            case inlineData = "inline_data"
        }
        
        init(text: String? = nil, inlineData: InlineData? = nil) {
            self.text = text
            self.inlineData = inlineData
        }
    }

    struct InlineData: Codable {
        let mimeType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case mimeType = "mime_type"
            case data
        }
    }

    struct Tool: Codable {
        struct GoogleSearch: Codable {}
        let googleSearch: GoogleSearch?

        enum CodingKeys: String, CodingKey {
            case googleSearch = "google_search"
        }
    }

    let contents: [ContentItem]
    let tools: [Tool]?
}


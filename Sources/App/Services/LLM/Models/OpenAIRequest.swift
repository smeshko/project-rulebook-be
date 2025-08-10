import Vapor

struct OpenAIRequest: Content {
    // Input can be either string or array of InputContent
    enum Input: Content {
        case text(String)
        case content([InputContent])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text):
                try container.encode(text)
            case .content(let content):
                try container.encode(content)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                self = .text(text)
            } else if let content = try? container.decode([InputContent].self) {
                self = .content(content)
            } else {
                throw DecodingError.typeMismatch(Input.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [InputContent]"))
            }
        }
    }
    
    struct InputContent: Content {
        protocol ContentType: Content, Codable {
            var type: String { get }
        }

        struct TextContent: ContentType {
            let type: String
            let text: String

            init(text: String) {
                self.type = "input_text"
                self.text = text
            }
        }

        struct ImageContent: ContentType {
            let type: String
            let imageUrl: ImageUrl
            
            struct ImageUrl: Content {
                let url: String
            }

            init(imageUrl: String) {
                self.type = "input_image"
                self.imageUrl = ImageUrl(url: imageUrl)
            }

            enum CodingKeys: String, CodingKey {
                case type
                case imageUrl = "image_url"
            }
        }
        
        let content: any ContentType

        enum CodingKeys: String, CodingKey {
            case type
        }

        enum ContentTypeCodingError: Error {
            case unknownType(String)
        }

        init(content: any ContentType) {
            self.content = content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)

            switch type {
            case "input_text":
                content = try TextContent(from: decoder)
            case "input_image":
                content = try ImageContent(from: decoder)
            default:
                throw ContentTypeCodingError.unknownType(type)
            }
        }

        func encode(to encoder: Encoder) throws {
            if let textContent = content as? TextContent {
                try textContent.encode(to: encoder)
            } else if let imageContent = content as? ImageContent {
                try imageContent.encode(to: encoder)
            }
        }
    }

    struct TextFormat: Content {
        let type: String
        
        static let json = TextFormat(type: "json_object")
        static let text = TextFormat(type: "text")
    }
    
    let model: String
    let input: Input?
    let instructions: String?
    let temperature: Double?
    let maxOutputTokens: Int?
    let text: TextFormat?
    
    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case temperature
        case maxOutputTokens = "max_output_tokens"
        case text
    }
}


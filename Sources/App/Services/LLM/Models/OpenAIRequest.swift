import Vapor

struct OpenAIRequest: Content {
    struct Message: Content {
        protocol ContentType: Content, Codable {
            var type: String { get }
        }

        struct TextContent: ContentType {
            let type: String
            let text: String

            init(type: String = "input_text", text: String) {
                self.type = type
                self.text = text
            }
        }

        struct ImageContent: ContentType {
            let type: String
            let imageUrl: String

            init(type: String = "input_image", imageUrl: String) {
                self.type = type
                self.imageUrl = imageUrl
            }

            enum CodingKeys: String, CodingKey {
                case type
                case imageUrl = "image_url"
            }
        }
        let role: String
        let content: [any ContentType]

        enum CodingKeys: String, CodingKey {
            case role, content
        }

        enum ContentTypeCodingError: Error {
            case unknownType(String)
        }

        enum ContentCodingKeys: String, CodingKey {
            case type
        }

        init(role: String, content: [any ContentType]) {
            self.role = role
            self.content = content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            role = try container.decode(String.self, forKey: .role)

            var contentContainer = try container.nestedUnkeyedContainer(forKey: .content)
            var tempContent = [any ContentType]()

            var tempContainer = contentContainer
            while !tempContainer.isAtEnd {
                let typeContainer = try tempContainer.nestedContainer(
                    keyedBy: ContentCodingKeys.self)
                let type = try typeContainer.decode(String.self, forKey: .type)

                switch type {
                case "text":
                    tempContent.append(try contentContainer.decode(TextContent.self))
                case "image_url":
                    tempContent.append(try contentContainer.decode(ImageContent.self))
                default:
                    throw ContentTypeCodingError.unknownType(type)
                }
            }
            content = tempContent
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            var contentContainer = container.nestedUnkeyedContainer(forKey: .content)

            for contentItem in content {
                if let textContent = contentItem as? TextContent {
                    try contentContainer.encode(textContent)
                } else if let imageContent = contentItem as? ImageContent {
                    try contentContainer.encode(imageContent)
                }
            }
        }
    }

    let model: String
    let input: [Message]
}

import Vapor

// MARK: - JSONValue

/// Lightweight enum for encoding arbitrary JSON structures (used for OpenAI JSON schemas).
enum JSONValue: Content, Equatable {
  case string(String)
  case number(Double)
  case bool(Bool)
  case null
  case array([JSONValue])
  case object([String: JSONValue])

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let s): try container.encode(s)
    case .number(let n): try container.encode(n)
    case .bool(let b): try container.encode(b)
    case .null: try container.encodeNil()
    case .array(let a): try container.encode(a)
    case .object(let o): try container.encode(o)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let b = try? container.decode(Bool.self) {
      self = .bool(b)
    } else if let n = try? container.decode(Double.self) {
      self = .number(n)
    } else if let s = try? container.decode(String.self) {
      self = .string(s)
    } else if let a = try? container.decode([JSONValue].self) {
      self = .array(a)
    } else if let o = try? container.decode([String: JSONValue].self) {
      self = .object(o)
    } else {
      throw DecodingError.typeMismatch(
        JSONValue.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "Unable to decode JSONValue"))
    }
  }
}

// MARK: - OpenAIRequest

struct OpenAIRequest: Content {
  // Input can be either string or array of messages
  enum Input: Content {
    case text(String)
    case messages([Message])
    case content([InputContent])

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .text(let text):
        try container.encode(text)
      case .messages(let messages):
        try container.encode(messages)
      case .content(let content):
        try container.encode(content)
      }
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let text = try? container.decode(String.self) {
        self = .text(text)
      } else if let messages = try? container.decode([Message].self) {
        self = .messages(messages)
      } else if let content = try? container.decode([InputContent].self) {
        self = .content(content)
      } else {
        throw DecodingError.typeMismatch(
          Input.self,
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription: "Expected String, [Message], or [InputContent]"))
      }
    }
  }

  struct Message: Content {
    let role: String
    let content: [InputContent]

    init(role: String, content: [InputContent]) {
      self.role = role
      self.content = content
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
      let imageUrl: String

      init(imageUrl: String) {
        self.type = "input_image"
        self.imageUrl = imageUrl
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

  // MARK: - Tool

  /// Represents an OpenAI tool (e.g., web_search_preview).
  struct Tool: Content {
    let type: String

    static let webSearch = Tool(type: "web_search_preview")
  }

  // MARK: - Text Configuration for Structured Output

  /// Configures the text output format, including JSON schema for structured output.
  struct TextConfig: Content {
    let format: FormatSpec

    struct FormatSpec: Content {
      let type: String
      let name: String?
      let strict: Bool?
      let schema: JSONValue?

      static let json = FormatSpec(type: "json_object", name: nil, strict: nil, schema: nil)
      static let text = FormatSpec(type: "text", name: nil, strict: nil, schema: nil)

      static func jsonSchema(name: String, schema: JSONValue) -> FormatSpec {
        FormatSpec(type: "json_schema", name: name, strict: true, schema: schema)
      }
    }
  }

  let model: String
  let input: Input?
  let instructions: String?
  let temperature: Double?
  let maxOutputTokens: Int?
  let text: TextConfig?
  let tools: [Tool]?

  enum CodingKeys: String, CodingKey {
    case model
    case input
    case instructions
    case temperature
    case maxOutputTokens = "max_output_tokens"
    case text
    case tools
  }
}

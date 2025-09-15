@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct GoogleGeminiServiceTests {

    @Test("Gemini service generates successful response")
    func successfulGeneration() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app

        let mockClient = GeminiMockHTTPClient(eventLoop: app.eventLoopGroup.next())
        app.clients.use { _ in mockClient }

        let expected = GeminiResponse(
            candidates: [
                .init(
                    content: .init(parts: [.init(text: "Test game rules")], role: "model"),
                    finishReason: "stop",
                    index: 0
                )
            ],
            usageMetadata: nil,
            modelVersion: nil,
            responseId: nil
        )
        mockClient.mockResponse = .success(expected)

        let service = GoogleGeminiService(app: app)
        let result = try await service.generate(input: "Generate rules")

        #expect(result == "Test game rules")
        #expect(mockClient.requestCount == 1)

        try await app.asyncShutdown()
    }

    @Test("Response text extraction works correctly")
    func responseTextExtraction() async throws {
        let normal = GeminiResponse(
            candidates: [
                .init(content: .init(parts: [.init(text: "Normal text")], role: nil), finishReason: "stop", index: 0)
            ],
            usageMetadata: nil,
            modelVersion: nil,
            responseId: nil
        )
        #expect(normal.extractText() == "Normal text")

        let fenced = GeminiResponse(
            candidates: [
                .init(content: .init(parts: [.init(text: "```json\n{\"a\":1}\n```")], role: nil), finishReason: "stop", index: 0)
            ],
            usageMetadata: nil,
            modelVersion: nil,
            responseId: nil
        )
        #expect(fenced.extractText() == "{\"a\":1}")

        let markdown = GeminiResponse(
            candidates: [
                .init(
                    content: .init(
                        parts: [
                            .init(text: "## Title\n- First item\n- Second item with [link](https://example.com) and `code`.\n> Quote line\n\n**Bold** and _italic_. ![alt](img.png)")
                        ],
                        role: nil
                    ),
                    finishReason: "stop",
                    index: 0
                )
            ],
            usageMetadata: nil,
            modelVersion: nil,
            responseId: nil
        )
        let expectedPlain = "Title\nFirst item\nSecond item with link and code.\nQuote line\n\nBold and italic. alt"
        #expect(markdown.extractText() == expectedPlain)

        let empty = GeminiResponse(candidates: [], usageMetadata: nil, modelVersion: nil, responseId: nil)
        #expect(empty.extractText() == nil)
    }
}

// MARK: - Mock HTTP Client for Gemini

final class GeminiMockHTTPClient: @unchecked Sendable, Client {
    var mockResponse: GeminiMockHTTPResponse?
    var requestCount = 0
    private let _eventLoop: EventLoop

    init(eventLoop: EventLoop? = nil) {
        self._eventLoop = eventLoop ?? EmbeddedEventLoop()
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        requestCount += 1
        let response = mockResponse ?? .serverError
        return eventLoop.makeSucceededFuture(response.clientResponse)
    }

    var eventLoop: EventLoop { _eventLoop }

    func delegating(to eventLoop: EventLoop) -> Client { GeminiMockHTTPClient(eventLoop: eventLoop) }
}

enum GeminiMockHTTPResponse {
    case success(GeminiResponse)
    case serverError

    var clientResponse: ClientResponse {
        switch self {
        case .success(let resp):
            var response = ClientResponse(status: .ok)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try! encoder.encode(resp)
            response.body = ByteBuffer(data: data)
            response.headers.add(name: "Content-Type", value: "application/json")
            return response
        case .serverError:
            return ClientResponse(status: .internalServerError)
        }
    }
}

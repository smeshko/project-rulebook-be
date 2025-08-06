@testable import App
import XCTVapor

final class OpenAIServiceTests: XCTestCase {
    var app: Application!
    var testWorld: TestWorld!
    
    override func setUpWithError() throws {
        app = Application(.testing)
        try configure(app)
        testWorld = try TestWorld(app: app)
    }
    
    override func tearDownWithError() throws {
        app?.shutdown()
    }
    
    func testSuccessfulGeneration() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        let expectedResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: .completed,
            error: nil,
            model: "gpt-4.1",
            output: [
                OpenAIResponse.OutputMessage(
                    id: "msg-1",
                    status: .completed,
                    content: [
                        OpenAIResponse.OutputMessage.OutputContent(text: "Test game rules")
                    ]
                )
            ],
            temperature: 0.7,
            usage: OpenAIResponse.Usage(
                inputTokens: 10,
                inputTokensDetails: OpenAIResponse.Usage.InputTokensDetails(cachedTokens: 0),
                outputTokens: 5,
                outputTokensDetails: OpenAIResponse.Usage.OutputTokensDetails(reasoningTokens: 0),
                totalTokens: 15
            )
        )
        
        mockClient.mockResponse = MockHTTPResponse.success(expectedResponse)
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Generate rules")]
            )
        ]
        
        // Act
        let result = try await service.generate(input: input)
        
        // Assert
        XCTAssertEqual(result, "Test game rules")
        XCTAssertEqual(mockClient.requestCount, 1)
    }
    
    func testRateLimitWithRetry() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        let rateLimitResponse = MockHTTPResponse.rateLimited()
        let successResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: .completed,
            error: nil,
            model: "gpt-4.1",
            output: [
                OpenAIResponse.OutputMessage(
                    id: "msg-1",
                    status: .completed,
                    content: [
                        OpenAIResponse.OutputMessage.OutputContent(text: "Success after retry")
                    ]
                )
            ],
            temperature: 0.7,
            usage: OpenAIResponse.Usage(
                inputTokens: 10,
                inputTokensDetails: OpenAIResponse.Usage.InputTokensDetails(cachedTokens: 0),
                outputTokens: 5,
                outputTokensDetails: OpenAIResponse.Usage.OutputTokensDetails(reasoningTokens: 0),
                totalTokens: 15
            )
        )
        
        // First call returns rate limit, second call succeeds
        mockClient.responses = [rateLimitResponse, MockHTTPResponse.success(successResponse)]
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Test")]
            )
        ]
        
        // Act
        let result = try await service.generate(input: input)
        
        // Assert
        XCTAssertEqual(result, "Success after retry")
        XCTAssertEqual(mockClient.requestCount, 2)
    }
    
    func testMaxRetriesExceeded() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.serverError()
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Test")]
            )
        ]
        
        // Act & Assert
        do {
            _ = try await service.generate(input: input)
            XCTFail("Expected error to be thrown")
        } catch let error as OpenAIError {
            switch error {
            case .serverError(let code):
                XCTAssertEqual(code, 500)
            default:
                XCTFail("Expected serverError, got \(error)")
            }
        }
        
        XCTAssertEqual(mockClient.requestCount, 3) // Should retry 3 times
    }
    
    func testAuthenticationFailure() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.unauthorized()
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Test")]
            )
        ]
        
        // Act & Assert
        do {
            _ = try await service.generate(input: input)
            XCTFail("Expected error to be thrown")
        } catch let error as OpenAIError {
            switch error {
            case .authenticationFailed:
                break // Expected
            default:
                XCTFail("Expected authenticationFailed, got \(error)")
            }
        }
        
        XCTAssertEqual(mockClient.requestCount, 1) // Should not retry auth failures
    }
    
    func testEmptyResponse() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        let emptyResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: .completed,
            error: nil,
            model: "gpt-4.1",
            output: [], // Empty output
            temperature: 0.7,
            usage: OpenAIResponse.Usage(
                inputTokens: 10,
                inputTokensDetails: OpenAIResponse.Usage.InputTokensDetails(cachedTokens: 0),
                outputTokens: 0,
                outputTokensDetails: OpenAIResponse.Usage.OutputTokensDetails(reasoningTokens: 0),
                totalTokens: 10
            )
        )
        
        mockClient.mockResponse = MockHTTPResponse.success(emptyResponse)
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Test")]
            )
        ]
        
        // Act & Assert
        do {
            _ = try await service.generate(input: input)
            XCTFail("Expected error to be thrown")
        } catch let error as OpenAIError {
            switch error {
            case .emptyResponse:
                break // Expected
            default:
                XCTFail("Expected emptyResponse, got \(error)")
            }
        }
    }
    
    func testInvalidJSONResponse() async throws {
        // Arrange
        let mockClient = MockHTTPClient()
        app.http.client.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.invalidJSON()
        
        let service = OpenAIService(app: app)
        let input = [
            OpenAIRequest.Message(
                role: "user",
                content: [OpenAIRequest.Message.TextContent(text: "Test")]
            )
        ]
        
        // Act & Assert
        do {
            _ = try await service.generate(input: input)
            XCTFail("Expected error to be thrown")
        } catch let error as OpenAIError {
            switch error {
            case .invalidResponse:
                break // Expected
            default:
                XCTFail("Expected invalidResponse, got \(error)")
            }
        }
    }
}

// MARK: - Mock HTTP Client

class MockHTTPClient: Client {
    var mockResponse: MockHTTPResponse?
    var responses: [MockHTTPResponse] = []
    var requestCount = 0
    
    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        requestCount += 1
        
        let response: MockHTTPResponse
        if !responses.isEmpty {
            response = responses.removeFirst()
        } else if let mockResponse = mockResponse {
            response = mockResponse
        } else {
            response = MockHTTPResponse.serverError()
        }
        
        return eventLoop.makeSucceededFuture(response.clientResponse)
    }
    
    var eventLoop: EventLoop {
        EmbeddedEventLoop()
    }
    
    func delegating(to eventLoop: EventLoop) -> Client {
        self
    }
}

// MARK: - Mock HTTP Responses

enum MockHTTPResponse {
    case success(OpenAIResponse)
    case rateLimited()
    case serverError()
    case unauthorized()
    case invalidJSON()
    
    var clientResponse: ClientResponse {
        switch self {
        case .success(let openAIResponse):
            let response = ClientResponse(status: .ok)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try! encoder.encode(openAIResponse)
            response.body = ByteBuffer(data: data)
            response.headers.add(name: "Content-Type", value: "application/json")
            return response
            
        case .rateLimited():
            let response = ClientResponse(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: "60")
            return response
            
        case .serverError():
            return ClientResponse(status: .internalServerError)
            
        case .unauthorized():
            return ClientResponse(status: .unauthorized)
            
        case .invalidJSON():
            let response = ClientResponse(status: .ok)
            response.body = ByteBuffer(string: "invalid json {")
            response.headers.add(name: "Content-Type", value: "application/json")
            return response
        }
    }
}
@testable import App
import VaporTesting
import Vapor
import Testing

@Suite(.serialized)
struct OpenAIServiceTests {
    
    @Test("OpenAI service generates successful response")
    func successfulGeneration() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        let expectedResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: "completed",
            model: "gpt-4o-mini",
            output: [
                OpenAIResponse.OutputItem(
                    id: "msg-1",
                    type: "message",
                    status: "completed",
                    role: "assistant",
                    content: [
                        OpenAIResponse.OutputItem.OutputContent(
                            type: "output_text",
                            text: "Test game rules"
                        )
                    ]
                )
            ],
            usage: OpenAIResponse.Usage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15
            ),
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        mockClient.mockResponse = MockHTTPResponse.success(expectedResponse)
        
        let service = OpenAIService(app: app)
        
        // Act
        let result = try await service.generate(input: "Generate rules")
        
        // Assert
        #expect(result == "Test game rules")
        #expect(mockClient.requestCount == 1)
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service retries on rate limit")
    func rateLimitWithRetry() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        let successResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: "completed",
            model: "gpt-4o-mini",
            output: [
                OpenAIResponse.OutputItem(
                    id: "msg-1",
                    type: "message",
                    status: "completed",
                    role: "assistant",
                    content: [
                        OpenAIResponse.OutputItem.OutputContent(
                            type: "output_text",
                            text: "Success after retry"
                        )
                    ]
                )
            ],
            usage: OpenAIResponse.Usage(
                promptTokens: 10,
                completionTokens: 5,
                totalTokens: 15
            ),
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        // First call returns rate limit, second call succeeds
        mockClient.responses = [MockHTTPResponse.rateLimited, MockHTTPResponse.success(successResponse)]
        
        let service = OpenAIService(app: app)
        
        // Act
        let result = try await service.generate(input: "Test")
        
        // Assert
        #expect(result == "Success after retry")
        #expect(mockClient.requestCount == 2)
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service fails after max retries exceeded")
    func maxRetriesExceeded() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.serverError
        
        let service = OpenAIService(app: app)
        
        // Act & Assert
        await #expect(throws: OpenAIError.self) {
            try await service.generate(input: "Test")
        }
        
        #expect(mockClient.requestCount == 3) // Should retry 3 times
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service handles authentication failure")
    func authenticationFailure() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.unauthorized
        
        let service = OpenAIService(app: app)
        
        // Act & Assert
        await #expect(throws: OpenAIError.self) {
            try await service.generate(input: "Test")
        }
        
        #expect(mockClient.requestCount == 1) // Should not retry auth failures
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service handles empty response")
    func emptyResponse() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        let emptyResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: "completed",
            model: "gpt-4o-mini",
            output: [], // Empty output
            usage: OpenAIResponse.Usage(
                promptTokens: 10,
                completionTokens: 0,
                totalTokens: 10
            ),
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        mockClient.mockResponse = MockHTTPResponse.success(emptyResponse)
        
        let service = OpenAIService(app: app)
        
        // Act & Assert
        await #expect(throws: OpenAIError.self) {
            try await service.generate(input: "Test")
        }
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service handles invalid JSON response")
    func invalidJSONResponse() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        mockClient.mockResponse = MockHTTPResponse.invalidJSON
        
        let service = OpenAIService(app: app)
        
        // Act & Assert
        await #expect(throws: OpenAIError.self) {
            try await service.generate(input: "Test")
        }
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("OpenAI service handles optimized generation with custom parameters")
    func generateOptimizedWithCustomParameters() async throws {
        // Arrange - Create app using new async API
        let app = try await TestWorld.makeTestApp()
        
        let mockClient = MockHTTPClient()
        app.clients.use { _ in mockClient }
        
        let expectedResponse = OpenAIResponse(
            id: "test-id",
            object: "response",
            createdAt: 1234567890,
            status: "completed",
            model: "gpt-4",
            output: [
                OpenAIResponse.OutputItem(
                    id: "msg-1",
                    type: "message",
                    status: "completed",
                    role: "assistant",
                    content: [
                        OpenAIResponse.OutputItem.OutputContent(
                            type: "output_text",
                            text: "Custom response"
                        )
                    ]
                )
            ],
            usage: OpenAIResponse.Usage(
                promptTokens: 20,
                completionTokens: 10,
                totalTokens: 30
            ),
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: 2000
        )
        
        mockClient.mockResponse = MockHTTPResponse.success(expectedResponse)
        
        let service = OpenAIService(app: app)
        
        // Act
        let result = try await service.generateOptimized(
            input: "Custom prompt",
            model: "gpt-4",
            temperature: 0.7,
            maxTokens: 2000,
            useJSONMode: false
        )
        
        // Assert
        #expect(result == "Custom response")
        #expect(mockClient.requestCount == 1)
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("Response text extraction works correctly")
    func responseTextExtraction() async throws {
        // Test extractText() method with various formats
        
        // Test normal response
        let normalResponse = OpenAIResponse(
            id: "test",
            object: "response",
            createdAt: nil,
            status: "completed",
            model: nil,
            output: [
                OpenAIResponse.OutputItem(
                    id: "msg",
                    type: "message",
                    status: "completed",
                    role: "assistant",
                    content: [
                        OpenAIResponse.OutputItem.OutputContent(
                            type: "output_text",
                            text: "Normal text"
                        )
                    ]
                )
            ],
            usage: nil,
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        #expect(normalResponse.extractText() == "Normal text")
        
        // Test JSON markdown format
        let jsonResponse = OpenAIResponse(
            id: "test",
            object: "response",
            createdAt: nil,
            status: "completed",
            model: nil,
            output: [
                OpenAIResponse.OutputItem(
                    id: "msg",
                    type: "message",
                    status: "completed",
                    role: "assistant",
                    content: [
                        OpenAIResponse.OutputItem.OutputContent(
                            type: "output_text",
                            text: "```json\n{\"key\":\"value\"}\n```"
                        )
                    ]
                )
            ],
            usage: nil,
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        #expect(jsonResponse.extractText() == "{\"key\":\"value\"}")
        
        // Test empty response
        let emptyResponse = OpenAIResponse(
            id: "test",
            object: "response",
            createdAt: nil,
            status: "completed",
            model: nil,
            output: [],
            usage: nil,
            error: nil,
            incompleteDetails: nil,
            instructions: nil,
            maxOutputTokens: nil
        )
        
        #expect(emptyResponse.extractText() == nil)
    }
}

// MARK: - Mock HTTP Client

final class MockHTTPClient: @unchecked Sendable, Client {
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
            response = MockHTTPResponse.serverError
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
    case rateLimited
    case serverError
    case unauthorized
    case invalidJSON
    
    var clientResponse: ClientResponse {
        switch self {
        case .success(let openAIResponse):
            var response = ClientResponse(status: .ok)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try! encoder.encode(openAIResponse)
            response.body = ByteBuffer(data: data)
            response.headers.add(name: "Content-Type", value: "application/json")
            return response
            
        case .rateLimited:
            var response = ClientResponse(status: .tooManyRequests)
            response.headers.add(name: "Retry-After", value: "0.1")  // 100ms for tests
            return response
            
        case .serverError:
            return ClientResponse(status: .internalServerError)
            
        case .unauthorized:
            return ClientResponse(status: .unauthorized)
            
        case .invalidJSON:
            var response = ClientResponse(status: .ok)
            response.body = ByteBuffer(string: "invalid json {")
            response.headers.add(name: "Content-Type", value: "application/json")
            return response
        }
    }
}
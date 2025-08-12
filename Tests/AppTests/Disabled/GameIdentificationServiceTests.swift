import Testing
import Vapor
@testable import App

/// Comprehensive tests for GameIdentificationService demonstrating domain service testing patterns.
///
/// This test suite validates complex AI-powered business logic in isolation,
/// including image analysis, caching strategies, security validation, and error handling.
final class GameIdentificationServiceTests {
    
    /// Test successful game identification with caching.
    @Test("Game identification analyzes image and caches results")
    func testSuccessfulGameIdentification() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIInputValidator()
        
        // Configure mock responses
        mockLLMService.nextResponse = """
        {
            "guessedTitle": "Ticket to Ride",
            "confidence": 0.95,
            "alternativeNames": ["TTR", "Ticket to Ride: Europe"],
            "recognizedText": ["Ticket to Ride", "2-5 Players", "Days of Wonder"],
            "notes": "Clear image with good lighting"
        }
        """
        
        let service = GameIdentificationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiInputValidator: mockValidator
        )
        
        let imageData = "fake-image-data".data(using: .utf8)!
        
        // Act
        let result = try await service.identifyGame(from: imageData)
        
        // Assert - Response Structure
        #expect(result.guessedTitle == "Ticket to Ride")
        #expect(result.confidence == 0.95)
        #expect(result.alternativeNames.contains("TTR"))
        #expect(result.recognizedText.contains("Ticket to Ride"))
        #expect(result.notes == "Clear image with good lighting")
        
        // Assert - LLM Service Called
        #expect(mockLLMService.requestCount == 1)
        #expect(mockLLMService.lastRequest?.input.count ?? 0 > 0)
        #expect(mockLLMService.lastRequest?.instructions.contains("game") ?? false)
        
        // Assert - Caching Behavior
        #expect(mockCacheService.getCalls.count == 1) // Cache lookup
        #expect(mockCacheService.setCalls.count == 1) // Cache storage
        
        // Verify cache key generation
        let cacheCall = mockCacheService.setCalls.first!
        #expect(cacheCall.key.hasPrefix("game-identification:"))
        #expect(cacheCall.ttl == 604800) // 7 days in seconds
    }
    
    /// Test cache hit scenario.
    @Test("Game identification returns cached results when available")
    func testCacheHitScenario() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIInputValidator()
        
        // Configure cache hit
        let cachedResponse = GameIdentificationResponse(
            guessedTitle: "Cached Game",
            confidence: 0.88,
            alternativeNames: ["Cached"],
            recognizedText: ["Cached Game"],
            notes: "From cache"
        )
        mockCacheService.cachedValues["game-identification:test"] = cachedResponse
        
        let service = GameIdentificationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiInputValidator: mockValidator
        )
        
        let imageData = "test".data(using: .utf8)!
        
        // Act
        let result = try await service.identifyGame(from: imageData)
        
        // Assert - Returns cached result
        #expect(result.guessedTitle == "Cached Game")
        #expect(result.notes == "From cache")
        
        // Assert - LLM not called
        #expect(mockLLMService.requestCount == 0)
        
        // Assert - Cache checked but not set (already exists)
        #expect(mockCacheService.getCalls.count == 1)
        #expect(mockCacheService.setCalls.count == 0)
    }
    
    /// Test input validation failure.
    @Test("Game identification validates input and rejects invalid images")
    func testInputValidationFailure() async throws {
        // Arrange
        let mockValidator = MockAIInputValidator()
        mockValidator.shouldThrowValidationError = true
        
        let service = GameIdentificationService(
            llmService: FakeLLMService(),
            aiCacheService: MockAICacheService(),
            aiInputValidator: mockValidator
        )
        
        let invalidImageData = Data()
        
        // Act & Assert
        await #expect(throws: AIValidationError.invalidImageFormat) {
            try await service.identifyGame(from: invalidImageData)
        }
    }
    
    /// Test LLM service failure handling.
    @Test("Game identification handles LLM service failures gracefully")
    func testLLMServiceFailure() async throws {
        // Arrange
        let failingLLMService = FailingLLMService()
        let service = GameIdentificationService(
            llmService: failingLLMService,
            aiCacheService: MockAICacheService(),
            aiInputValidator: MockAIInputValidator()
        )
        
        let imageData = "valid-image".data(using: .utf8)!
        
        // Act & Assert
        await #expect(throws: ContentError.generationFailed) {
            try await service.identifyGame(from: imageData)
        }
    }
    
    /// Test malformed JSON response handling.
    @Test("Game identification handles malformed AI responses")
    func testMalformedResponseHandling() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        mockLLMService.nextResponse = "{ invalid json }"
        
        let service = GameIdentificationService(
            llmService: mockLLMService,
            aiCacheService: MockAICacheService(),
            aiInputValidator: MockAIInputValidator()
        )
        
        let imageData = "valid-image".data(using: .utf8)!
        
        // Act & Assert
        await #expect(throws: ContentError.generationFailed) {
            try await service.identifyGame(from: imageData)
        }
    }
    
    /// Test security validation of AI response.
    @Test("Game identification validates AI response for security threats")
    func testSecurityValidation() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockValidator = MockAIInputValidator()
        
        // Configure potentially malicious response
        mockLLMService.nextResponse = """
        {
            "guessedTitle": "Malicious Game <script>alert('xss')</script>",
            "confidence": 0.95,
            "alternativeNames": ["Safe Name"],
            "recognizedText": ["Normal Text"],
            "notes": "Contains suspicious content"
        }
        """
        
        mockValidator.shouldThrowSecurityError = true
        
        let service = GameIdentificationService(
            llmService: mockLLMService,
            aiCacheService: MockAICacheService(),
            aiInputValidator: mockValidator
        )
        
        let imageData = "image-data".data(using: .utf8)!
        
        // Act & Assert
        await #expect(throws: AIValidationError.suspiciousContent) {
            try await service.identifyGame(from: imageData)
        }
    }
    
    /// Test cache key generation consistency.
    @Test("Game identification generates consistent cache keys")
    func testCacheKeyConsistency() async throws {
        // Arrange
        let mockCacheService = MockAICacheService()
        let service = GameIdentificationService(
            llmService: FakeLLMService(),
            aiCacheService: mockCacheService,
            aiInputValidator: MockAIInputValidator()
        )
        
        let imageData = "consistent-test-data".data(using: .utf8)!
        
        // Act - Call twice with same data
        _ = try? await service.identifyGame(from: imageData)
        _ = try? await service.identifyGame(from: imageData)
        
        // Assert - Same cache key used
        #expect(mockCacheService.getCalls.count == 2)
        let firstKey = mockCacheService.getCalls[0].key
        let secondKey = mockCacheService.getCalls[1].key
        #expect(firstKey == secondKey)
        #expect(firstKey.hasPrefix("game-identification:"))
    }
}

// MARK: - Test Helper: Failing LLM Service

/// Mock LLM service that always fails for testing error handling.
private class FailingLLMService: LLMService {
    func generate(input: String) async throws -> String {
        throw ContentError.generationFailed(reason: "Test LLM failure")
    }
    
    func generateOptimized(
        input: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        useJSONMode: Bool
    ) async throws -> String {
        throw ContentError.generationFailed(reason: "Test LLM failure")
    }
    
    func analyzeImage(
        imageData: String,
        prompt: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        useJSONMode: Bool
    ) async throws -> String {
        throw ContentError.generationFailed(reason: "Test LLM failure")
    }
    
    func generateResponse(request: OpenAIRequest) async throws -> String {
        throw ContentError.generationFailed(reason: "Test LLM failure")
    }
    
    func `for`(_ request: Request) -> LLMService {
        return self
    }
}

// MARK: - Test Helper: Mock AI Input Validator

/// Mock AI input validator for testing validation scenarios.
private class MockAIInputValidator: @unchecked Sendable, AIInputValidatorServiceInterface {
    var shouldThrowValidationError = false
    var shouldThrowSecurityError = false
    
    func validateImageData(_ data: Data) throws {
        if shouldThrowValidationError {
            throw AIValidationError.invalidImageFormat
        }
    }
    
    func validateAIResponse<T>(_ response: T) throws where T: Codable {
        if shouldThrowSecurityError {
            throw AIValidationError.suspiciousContent
        }
    }
    
    func `for`(_ request: Request) -> AIInputValidatorServiceInterface {
        return self
    }
}
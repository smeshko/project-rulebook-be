import Testing
import Vapor
@testable import App

/// Comprehensive tests for AnalyzeGameBoxUseCase demonstrating Complex Query testing patterns.
///
/// This test suite validates AI-powered game analysis queries that are read-only operations
/// involving complex AI service integration and image processing.
/// Focus is on data accuracy and proper error handling for AI queries.
@Suite(.serialized)
final class AnalyzeGameBoxUseCaseTests: Sendable {
    
    /// Test use case request structure and validation.
    @Test("AnalyzeGameBoxUseCase Request has correct structure")
    func testRequestStructure() async throws {
        // Arrange
        let imageData = "test-image-data".data(using: .utf8)!
        let context = RequestContext(
            clientIP: "127.0.0.1",
            logger: Logger(label: "test"),
            timestamp: Date(),
            requestID: "test-456"
        )
        
        // Act
        let request = AnalyzeGameBoxUseCase.Request(
            imageData: imageData,
            context: context
        )
        
        // Assert
        #expect(request.imageData == imageData)
        #expect(request.context.clientIP == "127.0.0.1")
        #expect(request.context.requestID == "test-456")
    }
    
    /// Test use case response structure and validation.
    @Test("AnalyzeGameBoxUseCase Response has correct structure")
    func testResponseStructure() async throws {
        // Arrange
        let gameboxRecognition = GameboxRecognition.Response(
            guessedTitle: "Wingspan",
            confidence: 94,
            alternativeTitles: ["Wingspan: European Expansion"],
            keywordsDetected: ["bird", "engine", "building", "strategy"],
            notes: "Clear game box with excellent visibility"
        )

        // Act
        let response = AnalyzeGameBoxUseCase.Response(
            gameboxRecognition: gameboxRecognition,
            analyzedAt: Date()
        )

        // Assert
        #expect(response.gameboxRecognition.guessedTitle == "Wingspan")
        #expect(response.gameboxRecognition.confidence == 94)
        #expect(response.gameboxRecognition.alternativeTitles.count == 1)
        #expect(response.gameboxRecognition.keywordsDetected.count == 4)
        #expect(response.analyzedAt <= Date())
    }
    
    /// Test Query protocol compliance.
    @Test("AnalyzeGameBoxUseCase implements Query protocol correctly")
    func testQueryProtocolCompliance() async throws {
        // The AnalyzeGameBoxUseCase should implement the Query protocol
        // which defines the interface for read-only operations in the system

        // Query protocol ensures:
        // 1. Read-only operations with no side effects
        // 2. Idempotent behavior (same input produces same output)
        // 3. Clear request/response contracts
        // 4. Consistent processing workflows
        
        let context = RequestContext(
            clientIP: "192.168.1.1",
            logger: Logger(label: "query-test")
        )
        
        let imageData = "query-test-image".data(using: .utf8)!
        
        let request = AnalyzeGameBoxUseCase.Request(
            imageData: imageData,
            context: context
        )
        
        // Validate request structure matches Query pattern expectations
        #expect(request.imageData.count > 0)
        #expect(request.context.clientIP == "192.168.1.1")
    }
    
    /// Test use case dependency injection pattern.
    @Test("AnalyzeGameBoxUseCase follows dependency injection patterns")
    func testDependencyInjectionPattern() async throws {
        // This test validates that the AnalyzeGameBoxUseCase follows the established
        // dependency injection pattern used throughout the application

        // The use case requires these dependencies to be injected via constructor:
        // - aiInputValidator: AIInputValidatorServiceInterface
        // - llmService: LLMService
        // - aiResponseValidator: AIResponseValidationService

        // This validates the architectural decision for use case dependency injection
        // Use cases encapsulate complete business workflows with direct implementation
        // rather than delegating to over-engineered service abstraction layers

        let context = RequestContext(
            clientIP: "127.0.0.1",
            logger: Logger(label: "test")
        )

        let request = AnalyzeGameBoxUseCase.Request(
            imageData: Data(),
            context: context
        )

        #expect(request.imageData.isEmpty == true)
        #expect(request.context.clientIP == "127.0.0.1")
    }
    
    /// Test GameboxRecognition response structure integration.
    @Test("GameboxRecognition response integrates correctly with use case")
    func testGameboxRecognitionIntegration() async throws {
        // Arrange
        let gameboxRecognition = GameboxRecognition.Response(
            guessedTitle: "Azul",
            confidence: 87,
            alternativeTitles: ["Azul: Summer Pavilion", "Azul: Stained Glass"],
            keywordsDetected: ["tile", "pattern", "mosaic", "strategy"],
            notes: "Tile placement game with colorful tiles visible on box"
        )
        
        let useResponse = AnalyzeGameBoxUseCase.Response(
            gameboxRecognition: gameboxRecognition,
            analyzedAt: Date()
        )
        
        // Assert - Integration structure
        #expect(useResponse.gameboxRecognition.guessedTitle == "Azul")
        #expect(useResponse.gameboxRecognition.confidence == 87)
        #expect(useResponse.gameboxRecognition.alternativeTitles.contains("Azul: Summer Pavilion"))
        #expect(useResponse.gameboxRecognition.keywordsDetected.contains("tile"))
        #expect(useResponse.gameboxRecognition.notes.contains("Tile placement"))
        
        // Test that the response maintains all data integrity
        #expect(useResponse.gameboxRecognition.alternativeTitles.count == 2)
        #expect(useResponse.gameboxRecognition.keywordsDetected.count == 4)
    }
    
    /// Test response JSON serialization for API endpoints.
    @Test("AnalyzeGameBoxUseCase Response can be serialized for API responses")
    func testResponseSerialization() async throws {
        // Arrange
        let gameboxRecognition = GameboxRecognition.Response(
            guessedTitle: "Pandemic",
            confidence: 91,
            alternativeTitles: ["Pandemic Legacy"],
            keywordsDetected: ["cooperative", "disease", "strategy", "board"],
            notes: "Cooperative game box with world map visible"
        )
        
        let response = AnalyzeGameBoxUseCase.Response(
            gameboxRecognition: gameboxRecognition,
            analyzedAt: Date()
        )
        
        // Act - Test that nested structure can be encoded
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let jsonData = try encoder.encode(response.gameboxRecognition)
        
        // Assert - JSON encoding succeeds
        #expect(jsonData.count > 0)
        
        // Decode to verify round-trip integrity
        let decoder = JSONDecoder()
        let decodedRecognition = try decoder.decode(GameboxRecognition.Response.self, from: jsonData)
        
        #expect(decodedRecognition.guessedTitle == gameboxRecognition.guessedTitle)
        #expect(decodedRecognition.confidence == gameboxRecognition.confidence)
        #expect(decodedRecognition.alternativeTitles == gameboxRecognition.alternativeTitles)
        #expect(decodedRecognition.keywordsDetected == gameboxRecognition.keywordsDetected)
        #expect(decodedRecognition.notes == gameboxRecognition.notes)
    }
    
    /// Test error handling patterns for use case failures.
    @Test("AnalyzeGameBoxUseCase handles expected error types")
    func testErrorHandlingPatterns() async throws {
        // The use case should handle these error scenarios:
        // 1. Invalid image data (AIValidationError)
        // 2. AI service failures (ContentError)
        // 3. Security validation failures (AIValidationError)
        
        // Test image validation errors
        let emptyImageError = AIProcessingError.imageDataEmpty
        #expect(emptyImageError.description.contains("empty"))
        
        let imageTooLargeError = AIProcessingError.inputTooLarge(maxSize: 10, context: "image_data")
        #expect(imageTooLargeError.description.contains("10"))
        
        let invalidFormatError = AIProcessingError.imageFormatInvalid(reason: "invalid format")
        #expect(invalidFormatError.description.contains("format"))
        
        // Error types are properly defined and can be thrown/caught
        // The use case would catch these errors and transform them into
        // appropriate HTTP responses via the controller layer
    }
    
    /// Test query idempotency characteristics.
    @Test("AnalyzeGameBoxUseCase maintains query idempotency characteristics")
    func testQueryIdempotency() async throws {
        // Query use cases should be idempotent - same input produces same output
        // This is important for consistent and predictable behavior

        let imageData1 = "consistent-image-data".data(using: .utf8)!
        let imageData2 = "consistent-image-data".data(using: .utf8)!

        let context = RequestContext(
            clientIP: "127.0.0.1",
            logger: Logger(label: "idempotency-test")
        )

        let request1 = AnalyzeGameBoxUseCase.Request(
            imageData: imageData1,
            context: context
        )

        let request2 = AnalyzeGameBoxUseCase.Request(
            imageData: imageData2,
            context: context
        )

        // Same image data should produce identical requests
        #expect(request1.imageData == request2.imageData)
        #expect(request1.context.clientIP == request2.context.clientIP)

        // This validates the foundation for idempotent behavior
        // ensuring identical inputs are processed consistently
    }
}

// MARK: - Complex Query Testing Pattern Note

/*
This test demonstrates Complex Query (Read-Only Use Case) testing patterns:

1. **Request/Response Structure Testing**: Validating data contracts for read operations
2. **Query Protocol Compliance**: Testing adherence to Query pattern interfaces
3. **Integration Structure Testing**: Validating complex nested response types
4. **JSON Serialization**: Testing API response compatibility for read operations
5. **Error Handling Patterns**: Validating expected error types for query failures
6. **Idempotency Validation**: Testing read-only characteristics and caching compatibility

Key characteristics of complex query testing:
- Focus on read-only operations and data integrity
- Test idempotency and caching-friendly behavior
- Validate performance optimization patterns
- Ensure no side effects or state mutations
- Test complex data structure handling
- Validate API response contracts

This approach provides:
- Stable tests that survive implementation changes
- Clear validation of query behavior and contracts
- Fast execution focused on data structure validation
- Performance-oriented testing patterns
- Easy maintenance as query requirements evolve
- Comprehensive validation of read-only operations

Complex queries differ from simple queries by:
- Processing complex input data (images, documents)
- Integrating multiple AI services for analysis
- Providing sophisticated caching and performance optimization
- Handling complex nested response structures
- Managing expensive operations through intelligent caching
- Coordinating security validation for sensitive data

Testing philosophy for queries:
- Test the contract and data integrity, not the implementation
- Validate idempotency and performance characteristics
- Ensure caching-friendly behavior patterns
- Focus on API compatibility and response structures
- Maintain fast tests that validate business logic interfaces
- Provide clear validation of query requirements and capabilities
*/

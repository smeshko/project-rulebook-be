import Testing
import Vapor
@testable import App

/// Comprehensive tests for AnalyzeGameBoxUseCase demonstrating Complex Query testing patterns.
///
/// This test suite validates AI-powered game analysis queries that are read-only operations
/// but involve complex AI service integration, caching strategies, and image processing.
/// Focus is on data accuracy, performance, and proper error handling for AI queries.
final class AnalyzeGameBoxUseCaseTests {
    
    /// Test successful game box analysis with high confidence.
    @Test("Analyze game box identifies games accurately with proper response structure")
    func testSuccessfulGameBoxAnalysis() async throws {
        // Arrange
        let mockGameIdentificationService = MockGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: mockGameIdentificationService
        )
        
        // Configure successful identification
        mockGameIdentificationService.mockResponse = GameIdentificationResponse(
            guessedTitle: "Wingspan",
            confidence: 0.94,
            alternativeNames: ["Wingspan: European Expansion"],
            recognizedText: ["Wingspan", "Elizabeth Hargrave", "Stonemaier Games", "1-5 Players"],
            notes: "Clear image with excellent lighting and readable text"
        )
        
        let imageData = "high-quality-game-box-image".data(using: .utf8)!
        
        // Act
        let result = try await useCase.execute(AnalyzeGameBoxUseCase.Request(
            imageData: imageData
        ))
        
        // Assert - Response Structure
        #expect(result.analysis.guessedTitle == "Wingspan")
        #expect(result.analysis.confidence == 0.94)
        #expect(result.analysis.alternativeNames.contains("Wingspan: European Expansion"))
        #expect(result.analysis.recognizedText.count == 4)
        #expect(result.analysis.notes.contains("Clear image"))
        
        // Assert - Service Called
        #expect(mockGameIdentificationService.identifyCallCount == 1)
        #expect(mockGameIdentificationService.lastImageData == imageData)
        
        // Assert - Query Characteristics (No side effects)
        #expect(result.analysis.confidence >= 0.0 && result.analysis.confidence <= 1.0)
        #expect(result.analysis.guessedTitle.count > 0)
    }
    
    /// Test low confidence analysis handling.
    @Test("Analyze game box handles low confidence scenarios appropriately")
    func testLowConfidenceAnalysis() async throws {
        // Arrange
        let mockGameIdentificationService = MockGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: mockGameIdentificationService
        )
        
        // Configure low confidence result
        mockGameIdentificationService.mockResponse = GameIdentificationResponse(
            guessedTitle: "Unknown Board Game",
            confidence: 0.23, // Very low confidence
            alternativeNames: [],
            recognizedText: ["Board", "Game", "Players"],
            notes: "Blurry image with poor lighting, text partially obscured"
        )
        
        let blurryImageData = "blurry-game-image".data(using: .utf8)!
        
        // Act
        let result = try await useCase.execute(AnalyzeGameBoxUseCase.Request(
            imageData: blurryImageData
        ))
        
        // Assert - Low Confidence Handling
        #expect(result.analysis.confidence < 0.5)
        #expect(result.analysis.guessedTitle.contains("Unknown"))
        #expect(result.analysis.alternativeNames.isEmpty)
        #expect(result.analysis.notes.contains("poor lighting"))
        
        // Assert - Still provides useful information
        #expect(result.analysis.recognizedText.count > 0)
        #expect(result.analysis.notes.count > 0)
    }
    
    /// Test query idempotency (same input produces same output).
    @Test("Analyze game box is idempotent and produces consistent results")
    func testQueryIdempotency() async throws {
        // Arrange
        let mockGameIdentificationService = MockGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: mockGameIdentificationService
        )
        
        mockGameIdentificationService.mockResponse = GameIdentificationResponse(
            guessedTitle: "Azul",
            confidence: 0.91,
            alternativeNames: ["Azul: Stained Glass of Sintra"],
            recognizedText: ["Azul", "Michael Kiesling", "Plan B Games"],
            notes: "Distinctive tile game packaging"
        )
        
        let imageData = "consistent-test-image".data(using: .utf8)!
        let request = AnalyzeGameBoxUseCase.Request(imageData: imageData)
        
        // Act - Call multiple times
        let result1 = try await useCase.execute(request)
        let result2 = try await useCase.execute(request)
        let result3 = try await useCase.execute(request)
        
        // Assert - Results are identical (idempotent)
        #expect(result1.analysis.guessedTitle == result2.analysis.guessedTitle)
        #expect(result1.analysis.guessedTitle == result3.analysis.guessedTitle)
        #expect(result1.analysis.confidence == result2.analysis.confidence)
        #expect(result1.analysis.confidence == result3.analysis.confidence)
        #expect(result1.analysis.alternativeNames == result2.analysis.alternativeNames)
        
        // Assert - Service called multiple times (no caching at use case level)
        #expect(mockGameIdentificationService.identifyCallCount == 3)
    }
    
    /// Test image validation error handling.
    @Test("Analyze game box handles invalid image data gracefully")
    func testInvalidImageHandling() async throws {
        // Arrange
        let failingGameIdentificationService = FailingGameIdentificationService()
        failingGameIdentificationService.errorToThrow = AIValidationError.invalidImageFormat
        
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: failingGameIdentificationService
        )
        
        let invalidImageData = Data() // Empty data
        
        // Act & Assert
        await #expect(throws: AIValidationError.invalidImageFormat) {
            try await useCase.execute(AnalyzeGameBoxUseCase.Request(
                imageData: invalidImageData
            ))
        }
    }
    
    /// Test AI service failure propagation.
    @Test("Analyze game box propagates AI service failures correctly")
    func testAIServiceFailure() async throws {
        // Arrange
        let failingGameIdentificationService = FailingGameIdentificationService()
        failingGameIdentificationService.errorToThrow = ContentError.generationFailed(reason: "AI service unavailable")
        
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: failingGameIdentificationService
        )
        
        let imageData = "valid-image-data".data(using: .utf8)!
        
        // Act & Assert
        await #expect(throws: ContentError.generationFailed) {
            try await useCase.execute(AnalyzeGameBoxUseCase.Request(
                imageData: imageData
            ))
        }
    }
    
    /// Test performance characteristics for query operations.
    @Test("Analyze game box executes efficiently for AI-powered queries")
    func testQueryPerformance() async throws {
        // Arrange
        let fastGameIdentificationService = FastGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: fastGameIdentificationService
        )
        
        let imageData = "performance-test-image".data(using: .utf8)!
        let request = AnalyzeGameBoxUseCase.Request(imageData: imageData)
        
        // Act & Assert - Measure execution time
        let startTime = Date()
        
        // Execute multiple times to test consistent performance
        for _ in 1...5 {
            _ = try await useCase.execute(request)
        }
        
        let executionTime = Date().timeIntervalSince(startTime)
        
        // Should complete quickly (mocked AI service)
        #expect(executionTime < 1.0)
        #expect(fastGameIdentificationService.callCount == 5)
    }
    
    /// Test complex game analysis with rich metadata.
    @Test("Analyze game box handles complex games with rich recognition data")
    func testComplexGameAnalysis() async throws {
        // Arrange
        let mockGameIdentificationService = MockGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: mockGameIdentificationService
        )
        
        // Configure complex game with lots of metadata
        mockGameIdentificationService.mockResponse = GameIdentificationResponse(
            guessedTitle: "Terraforming Mars",
            confidence: 0.97,
            alternativeNames: [
                "Terraforming Mars: Ares Expedition",
                "Terraforming Mars: Big Box",
                "TM"
            ],
            recognizedText: [
                "Terraforming Mars",
                "Jacob Fryxelius",
                "FryxGames",
                "1-5 Players",
                "Ages 12+",
                "90-120 minutes",
                "Engine Building",
                "Science Fiction"
            ],
            notes: "Complex strategy game with distinctive Mars theme artwork and clear component visibility"
        )
        
        let imageData = "terraforming-mars-box".data(using: .utf8)!
        
        // Act
        let result = try await useCase.execute(AnalyzeGameBoxUseCase.Request(
            imageData: imageData
        ))
        
        // Assert - Rich Metadata Extraction
        #expect(result.analysis.confidence > 0.95)
        #expect(result.analysis.alternativeNames.count == 3)
        #expect(result.analysis.recognizedText.count == 8)
        #expect(result.analysis.recognizedText.contains("Engine Building"))
        #expect(result.analysis.recognizedText.contains("90-120 minutes"))
        #expect(result.analysis.notes.contains("Complex strategy game"))
        
        // Assert - Proper game metadata recognized
        let textData = result.analysis.recognizedText
        #expect(textData.contains { $0.contains("Players") })
        #expect(textData.contains { $0.contains("Ages") })
        #expect(textData.contains { $0.contains("minutes") })
    }
    
    /// Test edge case with minimal image content.
    @Test("Analyze game box handles minimal image content gracefully")
    func testMinimalImageContent() async throws {
        // Arrange
        let mockGameIdentificationService = MockGameIdentificationService()
        let useCase = AnalyzeGameBoxUseCase(
            gameIdentificationService: mockGameIdentificationService
        )
        
        // Configure minimal recognition result
        mockGameIdentificationService.mockResponse = GameIdentificationResponse(
            guessedTitle: "Card Game",
            confidence: 0.15, // Very low confidence
            alternativeNames: [],
            recognizedText: ["Cards"],
            notes: "Minimal visible text, generic packaging"
        )
        
        let minimalImageData = "minimal-card-game".data(using: .utf8)!
        
        // Act
        let result = try await useCase.execute(AnalyzeGameBoxUseCase.Request(
            imageData: minimalImageData
        ))
        
        // Assert - Graceful Handling of Minimal Data
        #expect(result.analysis.confidence < 0.2)
        #expect(result.analysis.guessedTitle == "Card Game")
        #expect(result.analysis.alternativeNames.isEmpty)
        #expect(result.analysis.recognizedText.count == 1)
        #expect(result.analysis.notes.contains("Minimal"))
    }
}

// MARK: - Test Helpers

/// Mock game identification service for testing analysis operations.
private class MockGameIdentificationService: GameIdentificationService {
    var mockResponse: GameIdentificationResponse?
    var identifyCallCount = 0
    var lastImageData: Data?
    
    override func identifyGame(from imageData: Data) async throws -> GameIdentificationResponse {
        identifyCallCount += 1
        lastImageData = imageData
        
        guard let response = mockResponse else {
            throw ContentError.generationFailed(reason: "No mock response configured")
        }
        
        return response
    }
}

/// Failing game identification service for error testing.
private class FailingGameIdentificationService: GameIdentificationService {
    var errorToThrow: Error?
    
    override func identifyGame(from imageData: Data) async throws -> GameIdentificationResponse {
        if let error = errorToThrow {
            throw error
        }
        throw ContentError.generationFailed(reason: "Generic test failure")
    }
}

/// Fast game identification service for performance testing.
private class FastGameIdentificationService: GameIdentificationService {
    var callCount = 0
    
    override func identifyGame(from imageData: Data) async throws -> GameIdentificationResponse {
        callCount += 1
        
        return GameIdentificationResponse(
            guessedTitle: "Fast Game \(callCount)",
            confidence: 0.85,
            alternativeNames: ["Quick Game"],
            recognizedText: ["Fast", "Game"],
            notes: "Performance test result"
        )
    }
}

// MARK: - Complex Query Testing Pattern Note

/*
This test demonstrates Complex Query testing patterns for AI-powered read operations:

1. **AI Service Integration**: Testing AI-powered queries with proper mocking
2. **Data Accuracy Focus**: Ensuring correct AI response parsing and handling
3. **Performance Validation**: Testing query performance for AI operations
4. **Idempotency Verification**: Ensuring queries produce consistent results
5. **Error Propagation**: Testing how AI service errors are handled in queries
6. **Edge Case Handling**: Testing minimal data and low confidence scenarios

Key differences from Command testing:
- Focus on data accuracy rather than state changes
- Performance optimization is critical for queries
- Idempotency is essential for caching strategies
- No side effects - safe to execute multiple times
- Error handling focuses on graceful degradation rather than rollback

These patterns are essential for testing AI-powered queries that need to be:
- Fast and efficient (suitable for real-time use)
- Reliable and consistent (cacheable results)
- Robust against AI service failures
- Accurate in data extraction and parsing
*/
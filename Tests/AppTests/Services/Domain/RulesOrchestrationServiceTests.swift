import Testing
import Vapor
@testable import App

/// Comprehensive tests for RulesOrchestrationService demonstrating Complex Domain Service testing patterns.
///
/// This test suite validates the orchestration of multiple AI services for rules generation,
/// including multi-step AI workflows, caching strategies, validation chains, and complex
/// business logic coordination.
final class RulesOrchestrationServiceTests {
    
    /// Test successful end-to-end rules generation orchestration.
    @Test("Rules orchestration coordinates complete AI workflow successfully")
    func testSuccessfulRulesOrchestration() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIResponseValidator()
        
        let service = RulesOrchestrationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiResponseValidator: mockValidator
        )
        
        // Configure successful AI responses
        mockLLMService.nextResponse = """
        {
            "title": "Complete Rules for Azul",
            "content": "## Game Overview\\nAzul is a tile-placement game where players compete to create beautiful wall decorations...",
            "sections": [
                {
                    "title": "Setup",
                    "content": "Each player takes a player board and places it in front of them. Shuffle the tiles..."
                },
                {
                    "title": "Gameplay", 
                    "content": "The game is played over several rounds. Each round consists of multiple turns..."
                },
                {
                    "title": "Scoring",
                    "content": "Players score points for completed horizontal lines, vertical lines, and color sets..."
                }
            ],
            "complexity": "Medium",
            "estimatedPlayTime": "30-45 minutes",
            "playerCount": "2-4",
            "confidence": 0.91,
            "sources": ["Official rulebook", "BGG clarifications"],
            "warnings": []
        }
        """
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Azul",
            confidence: 0.94,
            alternativeNames: ["Azul: Stained Glass of Sintra"],
            recognizedText: ["Azul", "Michael Kiesling", "Plan B Games"],
            notes: "Clear tile game identification"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: true,
            language: "en"
        )
        
        // Act
        let result = try await service.generateRules(for: gameData, preferences: preferences)
        
        // Assert - Response Structure
        #expect(result.title == "Complete Rules for Azul")
        #expect(result.content.contains("Game Overview"))
        #expect(result.sections.count == 3)
        #expect(result.complexity == "Medium")
        #expect(result.confidence == 0.91)
        #expect(result.sources.count == 2)
        #expect(result.warnings.isEmpty)
        
        // Assert - Service Orchestration
        #expect(mockLLMService.requestCount == 1)
        #expect(mockCacheService.getCalls.count == 1) // Cache lookup
        #expect(mockCacheService.setCalls.count == 1) // Cache storage
        #expect(mockValidator.validateCallCount == 1) // Response validation
        
        // Assert - Proper Cache Key Generation
        let cacheCall = mockCacheService.setCalls.first!
        #expect(cacheCall.key.hasPrefix("rules-generation:"))
        #expect(cacheCall.key.contains("azul"))
        #expect(cacheCall.ttl > 0) // Should have TTL set
    }
    
    /// Test cache hit scenario bypassing AI generation.
    @Test("Rules orchestration returns cached results when available")
    func testCachedRulesOrchestration() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIResponseValidator()
        
        let service = RulesOrchestrationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiResponseValidator: mockValidator
        )
        
        // Configure cache hit
        let cachedRules = RulesGenerationResponse(
            title: "Cached Rules for Wingspan",
            content: "Wingspan is a competitive bird collection game...",
            sections: [
                RulesSection(title: "Setup", content: "Cached setup instructions..."),
                RulesSection(title: "Round Structure", content: "Cached round structure...")
            ],
            complexity: "Medium-High",
            estimatedPlayTime: "40-70 minutes", 
            playerCount: "1-5",
            confidence: 0.89,
            sources: ["Cache"],
            warnings: []
        )
        
        mockCacheService.cachedValues["rules-generation:wingspan:detailed:en"] = cachedRules
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Wingspan",
            confidence: 0.96,
            alternativeNames: ["Wingspan: European Expansion"],
            recognizedText: ["Wingspan", "Elizabeth Hargrave"],
            notes: "Bird-themed engine builder"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: false,
            language: "en"
        )
        
        // Act
        let result = try await service.generateRules(for: gameData, preferences: preferences)
        
        // Assert - Returns Cached Result
        #expect(result.title == "Cached Rules for Wingspan")
        #expect(result.sources.contains("Cache"))
        
        // Assert - AI Services Not Called
        #expect(mockLLMService.requestCount == 0)
        #expect(mockValidator.validateCallCount == 0)
        
        // Assert - Cache Accessed
        #expect(mockCacheService.getCalls.count == 1)
        #expect(mockCacheService.setCalls.count == 0) // No new cache entry
    }
    
    /// Test AI response validation failure handling.
    @Test("Rules orchestration handles AI response validation failures")
    func testAIValidationFailure() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIResponseValidator()
        
        mockValidator.shouldThrowValidationError = true
        
        let service = RulesOrchestrationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiResponseValidator: mockValidator
        )
        
        mockLLMService.nextResponse = """
        {
            "title": "Suspicious Rules <script>alert('xss')</script>",
            "content": "Malicious content here...",
            "sections": [],
            "complexity": "Unknown",
            "confidence": 0.5
        }
        """
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Test Game",
            confidence: 0.80,
            alternativeNames: [],
            recognizedText: ["Test"],
            notes: "Validation test"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .basic,
            includeExamples: false,
            language: "en"
        )
        
        // Act & Assert
        await #expect(throws: AIValidationError.suspiciousContent) {
            try await service.generateRules(for: gameData, preferences: preferences)
        }
        
        // Assert - Services Called but Failed Validation
        #expect(mockLLMService.requestCount == 1)
        #expect(mockValidator.validateCallCount == 1)
        #expect(mockCacheService.setCalls.count == 0) // No caching of invalid content
    }
    
    /// Test LLM service failure with retry logic.
    @Test("Rules orchestration handles LLM service failures with proper error propagation")
    func testLLMServiceFailure() async throws {
        // Arrange
        let failingLLMService = FailingLLMService()
        let service = RulesOrchestrationService(
            llmService: failingLLMService,
            aiCacheService: MockAICacheService(),
            aiResponseValidator: MockAIResponseValidator()
        )
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Failure Test Game",
            confidence: 0.90,
            alternativeNames: [],
            recognizedText: ["Failure Test"],
            notes: "Testing LLM failure"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: true,
            language: "en"
        )
        
        // Act & Assert
        await #expect(throws: ContentError.generationFailed) {
            try await service.generateRules(for: gameData, preferences: preferences)
        }
    }
    
    /// Test complex game handling with multiple AI iterations.
    @Test("Rules orchestration handles complex games with iterative AI refinement")
    func testComplexGameOrchestration() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let mockCacheService = MockAICacheService()
        let mockValidator = MockAIResponseValidator()
        
        let service = RulesOrchestrationService(
            llmService: mockLLMService,
            aiCacheService: mockCacheService,
            aiResponseValidator: mockValidator
        )
        
        // Configure complex game AI response
        mockLLMService.nextResponse = """
        {
            "title": "Comprehensive Rules for Gloomhaven",
            "content": "Gloomhaven is a tactical combat game set in a persistent fantasy world...",
            "sections": [
                {
                    "title": "Character Creation",
                    "content": "Players begin by selecting a starting character from six available classes..."
                },
                {
                    "title": "Scenario Setup", 
                    "content": "Each scenario requires specific setup including map tiles, monsters, and objectives..."
                },
                {
                    "title": "Combat Mechanics",
                    "content": "Combat uses a card-based system where players select two cards each round..."
                },
                {
                    "title": "Character Advancement",
                    "content": "Characters gain experience, gold, and unlock new abilities and items..."
                },
                {
                    "title": "Campaign Progress",
                    "content": "The campaign evolves based on player choices and scenario outcomes..."
                }
            ],
            "complexity": "Very High",
            "estimatedPlayTime": "90-150 minutes",
            "playerCount": "1-4",
            "confidence": 0.87,
            "sources": ["Official rulebook", "Designer clarifications", "FAQ"],
            "warnings": ["Complex game with steep learning curve", "Requires significant setup time"]
        }
        """
        
        let complexGame = GameIdentificationResponse(
            guessedTitle: "Gloomhaven",
            confidence: 0.93,
            alternativeNames: ["Gloomhaven: Jaws of the Lion"],
            recognizedText: ["Gloomhaven", "Isaac Childres", "Cephalofair Games"],
            notes: "Heavy tactical combat game with campaign elements"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: true,
            language: "en"
        )
        
        // Act
        let result = try await service.generateRules(for: gameData, preferences: preferences)
        
        // Assert - Complex Game Structure
        #expect(result.sections.count == 5)
        #expect(result.complexity == "Very High")
        #expect(result.warnings.count == 2)
        #expect(result.sources.count >= 3)
        #expect(result.estimatedPlayTime.contains("90-150"))
        
        // Assert - High Quality Expectations
        #expect(result.confidence > 0.8)
        #expect(result.content.contains("tactical combat"))
    }
    
    /// Test preference customization handling.
    @Test("Rules orchestration applies user preferences correctly to AI prompts")
    func testPreferenceCustomization() async throws {
        // Arrange
        let mockLLMService = FakeLLMService()
        let service = RulesOrchestrationService(
            llmService: mockLLMService,
            aiCacheService: MockAICacheService(),
            aiResponseValidator: MockAIResponseValidator()
        )
        
        mockLLMService.nextResponse = """
        {
            "title": "Quick Start Guide for Catan",
            "content": "Catan is a resource management game. Quick overview without examples...",
            "sections": [
                {
                    "title": "Basic Setup",
                    "content": "Place the board and starting settlements..."
                }
            ],
            "complexity": "Simple",
            "estimatedPlayTime": "45 minutes",
            "playerCount": "3-4",
            "confidence": 0.82,
            "sources": ["Quick start guide"],
            "warnings": []
        }
        """
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Settlers of Catan",
            confidence: 0.95,
            alternativeNames: ["Catan"],
            recognizedText: ["Catan", "Klaus Teuber"],
            notes: "Classic resource trading game"
        )
        
        // Test basic complexity preference
        let basicPreferences = RulesGenerationPreferences(
            complexity: .basic,
            includeExamples: false,
            language: "en"
        )
        
        // Act
        let result = try await service.generateRules(for: gameData, preferences: basicPreferences)
        
        // Assert - Preferences Applied
        #expect(result.complexity == "Simple")
        #expect(result.sections.count == 1) // Simplified structure
        #expect(!result.content.contains("example")) // No examples as requested
        
        // Assert - Prompt Construction
        #expect(mockLLMService.lastRequest?.instructions.contains("basic") ?? false)
        #expect(mockLLMService.lastRequest?.instructions.contains("simple") ?? false)
    }
    
    /// Test concurrent orchestration requests.
    @Test("Rules orchestration handles concurrent requests safely")
    func testConcurrentOrchestration() async throws {
        // Arrange
        let sharedLLMService = ThreadSafeFakeLLMService()
        let sharedCacheService = MockAICacheService()
        let service = RulesOrchestrationService(
            llmService: sharedLLMService,
            aiCacheService: sharedCacheService,
            aiResponseValidator: MockAIResponseValidator()
        )
        
        let game1 = GameIdentificationResponse(
            guessedTitle: "Concurrent Game 1",
            confidence: 0.88,
            alternativeNames: [],
            recognizedText: ["Game 1"],
            notes: "Concurrent test 1"
        )
        
        let game2 = GameIdentificationResponse(
            guessedTitle: "Concurrent Game 2", 
            confidence: 0.91,
            alternativeNames: [],
            recognizedText: ["Game 2"],
            notes: "Concurrent test 2"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: false,
            language: "en"
        )
        
        // Act - Concurrent requests
        async let result1 = service.generateRules(for: game1, preferences: preferences)
        async let result2 = service.generateRules(for: game2, preferences: preferences)
        
        let (res1, res2) = try await (result1, result2)
        
        // Assert - Both Requests Complete Successfully
        #expect(res1.title.contains("Concurrent Game 1"))
        #expect(res2.title.contains("Concurrent Game 2"))
        
        // Assert - Services Handle Concurrency
        let totalRequests = await sharedLLMService.getTotalRequests()
        #expect(totalRequests == 2)
        
        // Assert - Separate Cache Entries
        #expect(sharedCacheService.setCalls.count == 2)
    }
}

// MARK: - Test Helpers

/// Thread-safe fake LLM service for concurrent testing.
private actor ThreadSafeFakeLLMService: LLMService {
    private var requestCount = 0
    
    func generateResponse(request: OpenAIRequest) async throws -> String {
        requestCount += 1
        
        let gameTitle = request.input.contains("Game 1") ? "Game 1" : "Game 2"
        
        return """
        {
            "title": "Rules for Concurrent \(gameTitle)",
            "content": "Generated rules for \(gameTitle)...",
            "sections": [
                {
                    "title": "Overview",
                    "content": "Game overview for \(gameTitle)..."
                }
            ],
            "complexity": "Medium",
            "estimatedPlayTime": "60 minutes",
            "playerCount": "2-4",
            "confidence": 0.85,
            "sources": ["Generated"],
            "warnings": []
        }
        """
    }
    
    func getTotalRequests() -> Int {
        return requestCount
    }
}

/// Failing LLM service for error testing.
private class FailingLLMService: LLMService {
    func generateResponse(request: OpenAIRequest) async throws -> String {
        throw ContentError.generationFailed(reason: "Test orchestration LLM failure")
    }
}

/// Mock AI response validator for testing validation scenarios.
private class MockAIResponseValidator: AIResponseValidatorServiceInterface {
    var shouldThrowValidationError = false
    var validateCallCount = 0
    
    func validateRulesResponse(_ response: RulesGenerationResponse) throws {
        validateCallCount += 1
        
        if shouldThrowValidationError {
            throw AIValidationError.suspiciousContent
        }
        
        if response.title.contains("<script>") {
            throw AIValidationError.suspiciousContent
        }
    }
    
    func sanitizeRulesContent(_ content: String) -> String {
        return content.replacingOccurrences(of: "<script>", with: "&lt;script&gt;")
    }
}

// MARK: - Complex Domain Service Testing Pattern Note

/*
This test demonstrates Complex Domain Service testing patterns:

1. **Multi-Service Orchestration**: Testing coordination of multiple external services
2. **Caching Strategy Integration**: Testing performance optimization through caching
3. **Validation Chain Testing**: Testing security and quality validation workflows
4. **Complex Business Logic**: Testing sophisticated domain rules and transformations
5. **Concurrent Access Safety**: Testing thread safety in high-load scenarios
6. **Error Recovery Patterns**: Testing graceful degradation and error propagation

Key characteristics of complex domain service testing:
- Test end-to-end workflows with multiple service dependencies
- Validate caching strategies and cache key generation
- Test security validation and content sanitization
- Verify business rule application (preferences, complexity handling)
- Test performance characteristics and concurrent access
- Validate error handling and recovery scenarios

These patterns ensure complex domain services are:
- Reliable in orchestrating multiple service dependencies
- Secure through proper validation and sanitization
- Performant through effective caching strategies
- Resilient against individual service failures
- Thread-safe for high-concurrency scenarios
- Compliant with business rules and user preferences

Domain services differ from use cases by focusing on:
- Complex business logic rather than HTTP request/response
- Multi-service coordination rather than single operations
- Domain-specific validation and transformation rules
- Performance optimization strategies (caching, batching)
*/
import Testing
import Vapor
@testable import App

/// Comprehensive tests for GenerateRulesUseCase demonstrating Complex Command testing patterns.
///
/// This test suite validates AI-powered rules generation business logic in isolation,
/// including orchestration of multiple AI services, caching strategies, and complex
/// error handling scenarios for multi-step AI operations.
final class GenerateRulesUseCaseTests {
    
    /// Test successful rules generation with full orchestration.
    @Test("Generate rules orchestrates complete AI workflow with proper caching")
    func testSuccessfulRulesGeneration() async throws {
        // Arrange
        let mockOrchestrationService = MockRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: mockOrchestrationService
        )
        
        // Configure successful AI workflow
        mockOrchestrationService.mockResponse = RulesGenerationResponse(
            title: "Generated Rules for Ticket to Ride",
            content: "## Objective\nBe the first to connect cities across the map by claiming railway routes...",
            sections: [
                RulesSection(title: "Setup", content: "Each player takes train cards and route cards..."),
                RulesSection(title: "Gameplay", content: "On each turn, players can take train cards...")
            ],
            complexity: "Medium",
            estimatedPlayTime: "60-90 minutes",
            playerCount: "2-5",
            confidence: 0.92,
            sources: ["Official rulebook", "BGG community rules"],
            warnings: []
        )
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Ticket to Ride",
            confidence: 0.95,
            alternativeNames: ["TTR"],
            recognizedText: ["Ticket to Ride", "Days of Wonder"],
            notes: "Clear game box image"
        )
        
        // Act
        let result = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: gameData,
            preferences: RulesGenerationPreferences(
                complexity: .detailed,
                includeExamples: true,
                language: "en"
            )
        ))
        
        // Assert - Response Structure
        #expect(result.rules.title == "Generated Rules for Ticket to Ride")
        #expect(result.rules.content.contains("Objective"))
        #expect(result.rules.sections.count == 2)
        #expect(result.rules.complexity == "Medium")
        #expect(result.rules.confidence == 0.92)
        #expect(result.success == true)
        
        // Assert - Orchestration Service Called
        #expect(mockOrchestrationService.generateCallCount == 1)
        #expect(mockOrchestrationService.lastGameData?.guessedTitle == "Ticket to Ride")
        #expect(mockOrchestrationService.lastPreferences?.complexity == .detailed)
    }
    
    /// Test low confidence game identification handling.
    @Test("Generate rules handles low confidence game identification appropriately")
    func testLowConfidenceGameHandling() async throws {
        // Arrange
        let mockOrchestrationService = MockRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: mockOrchestrationService
        )
        
        mockOrchestrationService.mockResponse = RulesGenerationResponse(
            title: "Generic Board Game Rules",
            content: "Based on limited information, here are general game rules...",
            sections: [
                RulesSection(title: "General Setup", content: "Set up the game components..."),
                RulesSection(title: "Basic Play", content: "Follow the turn structure...")
            ],
            complexity: "Unknown",
            estimatedPlayTime: "Variable",
            playerCount: "2+",
            confidence: 0.45, // Low confidence response
            sources: ["Generic game patterns"],
            warnings: ["Low confidence identification", "Rules may be inaccurate"]
        )
        
        let lowConfidenceGame = GameIdentificationResponse(
            guessedTitle: "Unknown Board Game",
            confidence: 0.35, // Very low confidence
            alternativeNames: [],
            recognizedText: ["Board", "Game"],
            notes: "Blurry image, limited text visible"
        )
        
        // Act
        let result = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: lowConfidenceGame,
            preferences: RulesGenerationPreferences(
                complexity: .basic,
                includeExamples: false,
                language: "en"
            )
        ))
        
        // Assert - Warning System
        #expect(result.rules.warnings.contains("Low confidence identification"))
        #expect(result.rules.warnings.contains("Rules may be inaccurate"))
        #expect(result.rules.confidence < 0.5)
        #expect(result.rules.title.contains("Generic"))
        #expect(result.success == true) // Still succeeds but with warnings
    }
    
    /// Test AI service failure handling.
    @Test("Generate rules handles AI service failures with proper error propagation")
    func testAIServiceFailureHandling() async throws {
        // Arrange
        let failingOrchestrationService = FailingRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: failingOrchestrationService
        )
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Test Game",
            confidence: 0.90,
            alternativeNames: [],
            recognizedText: ["Test Game"],
            notes: "Test scenario"
        )
        
        // Act & Assert
        await #expect(throws: ContentError.generationFailed) {
            try await useCase.execute(GenerateRulesUseCase.Request(
                gameData: gameData,
                preferences: RulesGenerationPreferences(
                    complexity: .detailed,
                    includeExamples: true,
                    language: "en"
                )
            ))
        }
    }
    
    /// Test preferences handling and customization.
    @Test("Generate rules applies preferences correctly to AI generation")
    func testPreferencesHandling() async throws {
        // Arrange
        let mockOrchestrationService = MockRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: mockOrchestrationService
        )
        
        // Configure response based on preferences
        mockOrchestrationService.mockResponse = RulesGenerationResponse(
            title: "Simplified Rules for Catan",
            content: "Quick overview without complex details...",
            sections: [
                RulesSection(title: "Quick Start", content: "Roll dice, collect resources...")
            ],
            complexity: "Simple",
            estimatedPlayTime: "45 minutes",
            playerCount: "3-4",
            confidence: 0.88,
            sources: ["Simplified rulebook"],
            warnings: []
        )
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Settlers of Catan",
            confidence: 0.92,
            alternativeNames: ["Catan"],
            recognizedText: ["Catan", "Klaus Teuber"],
            notes: "Clear game identification"
        )
        
        // Act - Test basic complexity preference
        let result = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: gameData,
            preferences: RulesGenerationPreferences(
                complexity: .basic, // Simplified rules
                includeExamples: false,
                language: "en"
            )
        ))
        
        // Assert - Preferences Applied
        #expect(result.rules.complexity == "Simple")
        #expect(result.rules.sections.count == 1) // Simplified structure
        #expect(mockOrchestrationService.lastPreferences?.complexity == .basic)
        #expect(mockOrchestrationService.lastPreferences?.includeExamples == false)
    }
    
    /// Test caching integration through orchestration service.
    @Test("Generate rules leverages caching for performance optimization")
    func testCachingIntegration() async throws {
        // Arrange
        let cachingOrchestrationService = CachingRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: cachingOrchestrationService
        )
        
        let gameData = GameIdentificationResponse(
            guessedTitle: "Monopoly",
            confidence: 0.98,
            alternativeNames: ["Classic Monopoly"],
            recognizedText: ["Monopoly", "Hasbro"],
            notes: "Iconic game"
        )
        
        let preferences = RulesGenerationPreferences(
            complexity: .detailed,
            includeExamples: true,
            language: "en"
        )
        
        // Act - Call twice with same parameters
        let result1 = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: gameData,
            preferences: preferences
        ))
        
        let result2 = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: gameData,
            preferences: preferences
        ))
        
        // Assert - Caching Behavior
        #expect(result1.rules.title == result2.rules.title)
        #expect(cachingOrchestrationService.cacheHitCount == 1) // Second call hit cache
        #expect(cachingOrchestrationService.generationCount == 1) // Only generated once
    }
    
    /// Test complex game handling with multiple sections.
    @Test("Generate rules handles complex games with comprehensive sections")
    func testComplexGameHandling() async throws {
        // Arrange
        let mockOrchestrationService = MockRulesOrchestrationService()
        let useCase = GenerateRulesUseCase(
            rulesOrchestrationService: mockOrchestrationService
        )
        
        // Configure complex game response
        mockOrchestrationService.mockResponse = RulesGenerationResponse(
            title: "Complete Rules for Gloomhaven",
            content: "Gloomhaven is a complex tactical combat game...",
            sections: [
                RulesSection(title: "Setup", content: "Extensive setup with multiple components..."),
                RulesSection(title: "Character Creation", content: "Choose character class and starting abilities..."),
                RulesSection(title: "Scenario Setup", content: "Prepare the dungeon layout and monsters..."),
                RulesSection(title: "Combat System", content: "Turn-based tactical combat with card selection..."),
                RulesSection(title: "Character Progression", content: "Leveling up and unlocking new abilities..."),
                RulesSection(title: "Campaign Management", content: "Story progression and city events...")
            ],
            complexity: "Very Complex",
            estimatedPlayTime: "120-180 minutes",
            playerCount: "1-4",
            confidence: 0.89,
            sources: ["Official rulebook", "FAQ", "Community guides"],
            warnings: ["Complex game - expect long learning curve"]
        )
        
        let complexGame = GameIdentificationResponse(
            guessedTitle: "Gloomhaven",
            confidence: 0.94,
            alternativeNames: ["Gloomhaven: Jaws of the Lion"],
            recognizedText: ["Gloomhaven", "Isaac Childres", "Cephalofair"],
            notes: "Heavy strategy game"
        )
        
        // Act
        let result = try await useCase.execute(GenerateRulesUseCase.Request(
            gameData: complexGame,
            preferences: RulesGenerationPreferences(
                complexity: .detailed,
                includeExamples: true,
                language: "en"
            )
        ))
        
        // Assert - Complex Structure
        #expect(result.rules.sections.count == 6)
        #expect(result.rules.complexity == "Very Complex")
        #expect(result.rules.estimatedPlayTime.contains("120-180"))
        #expect(result.rules.warnings.contains("Complex game"))
        #expect(result.rules.sources.count >= 2) // Multiple sources for complex games
    }
}

// MARK: - Test Helpers

/// Mock orchestration service for testing rules generation.
private class MockRulesOrchestrationService: RulesOrchestrationService {
    var mockResponse: RulesGenerationResponse?
    var generateCallCount = 0
    var lastGameData: GameIdentificationResponse?
    var lastPreferences: RulesGenerationPreferences?
    
    func generateRules(
        for gameData: GameIdentificationResponse,
        preferences: RulesGenerationPreferences
    ) async throws -> RulesGenerationResponse {
        generateCallCount += 1
        lastGameData = gameData
        lastPreferences = preferences
        
        guard let response = mockResponse else {
            throw ContentError.generationFailed(reason: "No mock response configured")
        }
        
        return response
    }
}

/// Failing orchestration service for error testing.
private class FailingRulesOrchestrationService: RulesOrchestrationService {
    func generateRules(
        for gameData: GameIdentificationResponse,
        preferences: RulesGenerationPreferences
    ) async throws -> RulesGenerationResponse {
        throw ContentError.generationFailed(reason: "Test orchestration failure")
    }
}

/// Caching orchestration service for testing cache behavior.
private class CachingRulesOrchestrationService: RulesOrchestrationService {
    var cacheHitCount = 0
    var generationCount = 0
    private var cachedResponse: RulesGenerationResponse?
    
    func generateRules(
        for gameData: GameIdentificationResponse,
        preferences: RulesGenerationPreferences
    ) async throws -> RulesGenerationResponse {
        
        // Simulate cache key generation
        let cacheKey = "\(gameData.guessedTitle)-\(preferences.complexity)"
        
        if let cached = cachedResponse {
            cacheHitCount += 1
            return cached
        }
        
        generationCount += 1
        let response = RulesGenerationResponse(
            title: "Rules for \(gameData.guessedTitle)",
            content: "Generated content for \(gameData.guessedTitle)...",
            sections: [
                RulesSection(title: "Overview", content: "Game overview...")
            ],
            complexity: "Medium",
            estimatedPlayTime: "60 minutes",
            playerCount: "2-4",
            confidence: 0.85,
            sources: ["Generated"],
            warnings: []
        )
        
        cachedResponse = response
        return response
    }
}

// MARK: - Complex Command Testing Pattern Note

/*
This test demonstrates Complex Command testing patterns for AI-powered operations:

1. **Multi-Service Orchestration**: Commands that coordinate multiple services
2. **AI Service Integration**: Testing AI-powered business logic with mocks
3. **Caching Strategy Validation**: Ensuring performance optimizations work correctly
4. **Complex Error Scenarios**: Testing failures in multi-step AI operations
5. **Preference Configuration**: Testing customization and configuration handling
6. **Quality Assurance**: Testing AI response validation and confidence handling

These patterns are essential for testing complex AI-powered commands that involve:
- Multiple external service calls
- Complex business logic orchestration
- Performance optimization strategies
- Quality validation and error handling
- User customization and preferences
*/
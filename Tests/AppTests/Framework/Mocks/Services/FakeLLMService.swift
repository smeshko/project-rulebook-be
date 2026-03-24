@testable import App
import Foundation
import Vapor

/// Fake LLM service for testing that provides configurable responses.
///
/// This service implements the LLMService interface with predictable responses
/// for testing different scenarios. It supports token-optimized responses
/// and can be configured to simulate different AI model behaviors.
final class FakeLLMService: LLMService, @unchecked Sendable {
    private let application: Application
    private var configuredResponses: [String: String] = [:]
    private var defaultResponse: String
    private let logger: Logger
    
    /// Token-optimized response for board game box analysis (110 tokens)
    static let boxAnalysisResponse = """
    {
      "title": "Settlers of Catan",
      "confidence": 0.95,
      "players": "3-4",
      "age": "10+",
      "playtime": "60-90 minutes",
      "categories": ["Strategy", "Family"],
      "description": "Trade resources and build settlements in this classic Euro-style board game.",
      "components": ["Game board", "Resource cards", "Development cards", "Wooden pieces"],
      "publisher": "Catan Studio"
    }
    """
    
    /// Token-optimized response for rules generation (175 tokens)
    static let rulesGenerationResponse = """
    {
      "rules": {
        "setup": "Each player starts with 2 settlements and roads. Place the robber on the desert.",
        "gameplay": "Roll dice, collect resources, trade with players, build structures.",
        "winning": "First player to reach 10 victory points wins the game.",
        "turns": "Players take turns clockwise. On your turn: roll dice, trade, build.",
        "special": "When 7 is rolled, players with 8+ cards discard half and move the robber."
      },
      "confidence": 0.92,
      "complexity": "Medium"
    }
    """
    
    init(app: Application) {
        self.application = app
        self.logger = app.logger
        self.defaultResponse = Self.rulesGenerationResponse
        
        // Pre-configure common responses
        configureResponse(for: "board game box analysis", response: Self.boxAnalysisResponse)
        configureResponse(for: "generate rules", response: Self.rulesGenerationResponse)
        configureResponse(for: "chess rules", response: Self.rulesGenerationResponse)
    }
    
    /// Configure a specific response for a given input pattern.
    ///
    /// - Parameters:
    ///   - input: The input pattern to match (case-insensitive partial match)
    ///   - response: The response to return for matching inputs
    func configureResponse(for input: String, response: String) {
        configuredResponses[input.lowercased()] = response
    }
    
    /// Set the default response for unmatched inputs.
    ///
    /// - Parameter response: The default response to use
    func setDefaultResponse(_ response: String) {
        defaultResponse = response
    }
    
    /// Clear all configured responses and reset to default.
    func reset() {
        configuredResponses.removeAll()
        defaultResponse = Self.rulesGenerationResponse
    }
    
    // MARK: - LLMService Implementation
    
    func generate(input: String) async throws -> String {
        logger.info("FakeLLMService generating response for input: \(input.prefix(50))...")
        return findMatchingResponse(for: input)
    }
    
    func generateOptimized(input: String) async throws -> String {
        logger.info("FakeLLMService generating optimized response")
        return findMatchingResponse(for: input)
    }
    
    func analyzeImage(
        imageData: String,
        prompt: String
    ) async throws -> String {
        logger.info("FakeLLMService analyzing image with prompt: \(prompt.prefix(50))...")
        return findMatchingResponse(for: prompt)
    }

    func generateRules(systemPrompt: String, userPrompt: String) async throws -> String {
        logger.info("FakeLLMService generating rules for: \(userPrompt.prefix(50))...")
        return findMatchingResponse(for: userPrompt)
    }
    
    func `for`(_ request: Request) -> LLMService {
        return self
    }
    
    // MARK: - Private Methods
    
    private func findMatchingResponse(for input: String) -> String {
        let lowercaseInput = input.lowercased()
        
        // Look for configured responses that match the input
        for (pattern, response) in configuredResponses {
            if lowercaseInput.contains(pattern) {
                return response
            }
        }
        
        // Return default response if no pattern matches
        return defaultResponse
    }
}

// MARK: - Service Registration Extension

extension Application.Service.Provider where ServiceType == LLMService {
    /// Provides a fake LLM service for testing.
    static var fake: Self {
        .init { app in
            app.services.llm.use { FakeLLMService(app: $0) }
        }
    }
}

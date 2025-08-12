import Foundation
import Vapor

/// Domain service for orchestrating AI-powered game rules generation.
///
/// This service encapsulates the complex business logic for generating comprehensive
/// board game rules explanations using AI text generation. It coordinates existing
/// services to provide a clean, testable interface for rules generation.
protocol RulesOrchestrationService: Sendable {
    /// Generates comprehensive rules explanation for a board game.
    ///
    /// This method coordinates the complete rules generation workflow using
    /// existing services through the Vapor request context.
    ///
    /// - Parameters:
    ///   - gameTitle: Raw game title from user input  
    ///   - request: Vapor request for accessing services
    /// - Returns: Comprehensive rules explanation with structured content
    /// - Throws: AIValidationError for invalid input, ContentError for AI failures
    func generateRules(
        gameTitle: String,
        request: Request
    ) async throws -> RulesSummary.Response
}

/// Production implementation of RulesOrchestrationService.
final class DefaultRulesOrchestrationService: RulesOrchestrationService {
    
    init() {}
    
    func generateRules(
        gameTitle: String,
        request: Request
    ) async throws -> RulesSummary.Response {
        
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        
        request.logger.info("AI rules generation request initiated", metadata: [
            "endpoint": "generateRulesSummary",
            "client_ip": .string(clientIP),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // CRITICAL SECURITY FIX: Validate and sanitize game title before AI processing
        let sanitizedGameTitle: String
        do {
            sanitizedGameTitle = try request.services.aiInputValidator.validateAndSanitizeGameTitle(gameTitle)
        } catch let validationError as AIValidationError {
            request.logger.warning("Game title validation failed", metadata: [
                "error": .string(validationError.description),
                "raw_title": .string(gameTitle),
                "client_ip": .string(clientIP)
            ])
            throw validationError
        } catch let sanitizationError as ValidationError {
            request.logger.warning("Game title sanitization failed", metadata: [
                "error": .string(sanitizationError.description),
                "raw_title": .string(gameTitle),
                "client_ip": .string(clientIP)
            ])
            throw Abort(.badRequest, reason: sanitizationError.description)
        }
        
        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = request.services.cacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)
        
        if let cachedResponse = await request.services.aiCache.get(key: cacheKey) {
            request.logger.info("Cache hit for rules generation", metadata: [
                "game_title": .string(sanitizedGameTitle),
                "cache_key": .string(cacheKey),
                "client_ip": .string(clientIP)
            ])
            
            // Parse and return cached response
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let result = try JSONDecoder().decode(RulesSummary.Response.self, from: cachedBuffer)
            return result
        }
        
        request.logger.debug("Cache miss for rules generation", metadata: [
            "game_title": .string(sanitizedGameTitle),
            "cache_key": .string(cacheKey)
        ])
        
        // Enhanced prompt for comprehensive, consistent rule generation
        let systemPrompt = """
        You are an expert board game rules instructor. Generate a comprehensive rules guide for the specified game.
        
        Follow this content framework:
        1. Overview: Core concept and objective in 2-3 sentences
        2. Setup: Clear, numbered steps for game preparation
        3. First Round: Step-by-step guide for new players
        4. Victory: Win conditions and end game triggers
        5. Deep Dive: Advanced rules, special cases, strategy tips
        6. Resources: Helpful links for learning
        
        Return JSON with this exact structure:
        {
          "title": "exact game name",
          "playerCount": "X-Y players",
          "playTime": "X-Y minutes",
          "summary": "engaging 2-3 sentence overview explaining theme and main objective",
          "initialSetup": ["numbered setup steps", "be specific about component placement"],
          "firstRoundGuide": ["step-by-step first turn", "explain decision points", "show example moves"],
          "winCondition": "clear victory conditions and game end triggers",
          "deepDive": ["advanced strategies", "common rule clarifications", "variant rules if applicable"],
          "resources": {
            "videoLinks": ["up to 3 tutorial video suggestions"],
            "webLinks": ["official rules", "BGG page", "strategy guides"]
          },
          "confidence": 0-100,
          "notes": "mention any assumptions or uncertainties about specific rules"
        }
        
        Quality standards:
        - Use clear, friendly language appropriate for ages 10+
        - Number all setup steps and procedures
        - Include specific examples where helpful
        - Mention component names consistently
        - If unsure about exact rules, note assumptions
        
        Confidence scoring:
        - 90-100: Well-known game with established rules
        - 70-89: Familiar with game type, some details estimated
        - 50-69: Making educated guesses based on genre
        - Below 50: Unfamiliar game, using board game conventions
        """
        
        let userPrompt = "Game: \(sanitizedGameTitle)"
        
        // Create combined input with system instructions and user prompt
        let combinedPrompt = """
        \(systemPrompt)

        \(userPrompt)
        """
        
        let rulesResponse: String
        do {
            rulesResponse = try await request.services.llm.generateOptimized(
                input: combinedPrompt,
                model: "gpt-4o-mini",
                temperature: 0,
                maxTokens: 1000,
                useJSONMode: true
            )
        } catch {
            request.logger.error("LLM service error during rules generation", metadata: [
                "error": .string(error.localizedDescription),
                "game_title": .string(sanitizedGameTitle),
                "client_ip": .string(clientIP)
            ])
            throw ContentError.externalServiceFailedToRespond
        }
        
        // SECURITY FIX: Validate AI response before returning using validation service  
        do {
            let validationService = try await request.resolveService(AIResponseValidationService.self)
            let validatedResponse = try validationService.validateRulesSummaryResponse(
                rulesResponse,
                gameTitle: sanitizedGameTitle,
                clientIP: clientIP,
                logger: request.logger
            )
            let rulesBuffer = ByteBuffer(string: validatedResponse)
            let result = try JSONDecoder().decode(RulesSummary.Response.self, from: rulesBuffer)
            
            // PERFORMANCE OPTIMIZATION: Cache successful response
            let cacheConfig = try request.application.configuration.cache
            await request.services.aiCache.set(
                key: cacheKey,
                value: validatedResponse,
                ttl: cacheConfig.rulesGenerationTTL
            )
            
            // Log successful generation and caching
            request.logger.info("AI rules generation completed successfully", metadata: [
                "game_title": .string(sanitizedGameTitle),
                "confidence": .string("\(result.confidence)"),
                "cached": .string("true"),
                "cache_key": .string(cacheKey),
                "client_ip": .string(clientIP)
            ])
            
            return result
        } catch {
            request.logger.error("AI response validation failed for rules generation", metadata: [
                "error": .string(error.localizedDescription),
                "game_title": .string(sanitizedGameTitle),
                "response_length": .string("\(rulesResponse.count)"),
                "client_ip": .string(clientIP)
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }
}
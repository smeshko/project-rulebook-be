import Foundation
import Vapor

/// Use case for generating comprehensive board game rules explanations.
///
/// This use case orchestrates the complete rules generation workflow by coordinating
/// between domain services to provide reliable, cached, and secure rules generation.
/// It encapsulates the business logic for AI-powered rules creation while maintaining
/// clean separation from HTTP concerns and external service details.
///
/// ## Responsibilities
/// - **Workflow Orchestration**: Coordinates between multiple domain services
/// - **Business Logic**: Encapsulates rules generation business rules
/// - **Input Validation**: Ensures game titles are properly validated and sanitized
/// - **Error Handling**: Provides structured error handling and validation
/// - **Performance Management**: Leverages intelligent caching for cost efficiency
/// - **Security Enforcement**: Ensures all security validations are applied
///
/// ## Architecture Benefits
/// - **Testability**: Pure business logic without HTTP dependencies
/// - **Reusability**: Can be used by different interfaces (HTTP, CLI, etc.)
/// - **Maintainability**: Clear separation of concerns and dependencies
/// - **Scalability**: Efficient use of caching and external services
/// - **Cost Efficiency**: Intelligent caching reduces AI API costs significantly
struct GenerateRulesUseCase: Command {

    /// Request parameters for rules generation.
    struct Request {
        /// Game title for which rules should be generated
        let gameTitle: String
        /// Request context with client information and logging
        let context: RequestContext

        init(gameTitle: String, context: RequestContext) {
            self.gameTitle = gameTitle
            self.context = context
        }
    }

    /// Response from rules generation operation.
    struct Response {
        /// Comprehensive rules explanation with structured content
        let rulesSummary: RulesSummary.Response
        /// Original game title that was processed (may be sanitized)
        let processedGameTitle: String
        /// Timestamp when rules were generated
        let generatedAt: Date
        /// Whether result was served from cache (performance metric)
        let wasCached: Bool

        init(
            rulesSummary: RulesSummary.Response,
            processedGameTitle: String,
            generatedAt: Date = Date.now,
            wasCached: Bool = false
        ) {
            self.rulesSummary = rulesSummary
            self.processedGameTitle = processedGameTitle
            self.generatedAt = generatedAt
            self.wasCached = wasCached
        }
    }

    // MARK: - Dependencies

    /// Service for validating and sanitizing AI inputs
    private let aiInputValidator: AIInputValidatorServiceInterface
    /// Service for generating cache keys
    private let cacheKeyGenerator: CacheKeyGeneratorServiceInterface
    /// Service for caching AI responses
    private let aiCache: AICacheServiceInterface
    /// Service for LLM interactions
    private let llmService: LLMService
    /// Service for validating AI responses
    private let aiResponseValidator: AIResponseValidationService
    /// Cache configuration settings
    private let cacheConfiguration: CacheConfig

    // MARK: - Initialization

    init(
        aiInputValidator: AIInputValidatorServiceInterface,
        cacheKeyGenerator: CacheKeyGeneratorServiceInterface,
        aiCache: AICacheServiceInterface,
        llmService: LLMService,
        aiResponseValidator: AIResponseValidationService,
        cacheConfiguration: CacheConfig
    ) {
        self.aiInputValidator = aiInputValidator
        self.cacheKeyGenerator = cacheKeyGenerator
        self.aiCache = aiCache
        self.llmService = llmService
        self.aiResponseValidator = aiResponseValidator
        self.cacheConfiguration = cacheConfiguration
    }

    // MARK: - Use Case Execution

    /// Executes the rules generation use case.
    ///
    /// This method coordinates the complete rules generation workflow:
    /// 1. Validates input parameters and security requirements
    /// 2. Handles input sanitization and validation
    /// 3. Manages caching and performance optimization
    /// 4. Orchestrates AI model interaction with prompt engineering
    /// 5. Validates AI responses for security and quality
    /// 6. Returns structured response with comprehensive metadata
    ///
    /// ## Error Handling
    /// - Propagates AIProcessingError for invalid or malicious game titles or sanitization failures
    /// - Propagates ContentError for external service failures
    /// - Provides detailed logging for debugging and monitoring
    ///
    /// ## Performance Characteristics
    /// - Leverages intelligent caching for identical game titles
    /// - Returns cached results in sub-millisecond time
    /// - Reduces AI API costs through smart caching strategies
    /// - Uses 24-hour TTL for balanced freshness and cost efficiency
    ///
    /// ## Security Features
    /// - Advanced input validation and sanitization
    /// - Prompt injection prevention and detection
    /// - Response content filtering and validation
    /// - Comprehensive security logging for monitoring
    ///
    /// - Parameter request: Contains game title, client context, and logging
    /// - Returns: Comprehensive rules explanation with generation metadata
    /// - Throws: Service errors if validation fails or AI service unavailable
    func execute(_ request: Request) async throws -> Response {
        let context = request.context

        context.logger.info(
            "AI rules generation request initiated",
            metadata: [
                "endpoint": "generateRulesSummary",
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID),
                "timestamp": .string(ISO8601DateFormatter().string(from: context.timestamp)),
            ])

        // Basic input validation
        guard !request.gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Game title cannot be empty")
        }

        // Check for reasonable title length
        guard request.gameTitle.count <= 200 else {
            throw Abort(.badRequest, reason: "Game title too long (max 200 characters)")
        }

        // CRITICAL SECURITY FIX: Validate and sanitize game title before AI processing
        let sanitizedGameTitle: String
        do {
            sanitizedGameTitle = try aiInputValidator.validateAndSanitizeGameTitle(
                request.gameTitle)
        } catch let processingError as AIProcessingError {
            context.logger.warning(
                "Game title processing failed",
                metadata: [
                    "error": .string(processingError.description),
                    "raw_title": .string(request.gameTitle),
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                ])
            throw processingError
        }

        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = cacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)
        var wasCached = false

        if let cachedResponse = await aiCache.get(key: cacheKey) {
            context.logger.info(
                "Cache hit for rules generation",
                metadata: [
                    "game_title": .string(sanitizedGameTitle),
                    "cache_key": .string(cacheKey),
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                ])

            // Parse and return cached response
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let rulesSummary = try JSONDecoder().decode(
                RulesSummary.Response.self, from: cachedBuffer)
            wasCached = true

            let response = Response(
                rulesSummary: rulesSummary,
                processedGameTitle: rulesSummary.title,
                generatedAt: Date.now,
                wasCached: wasCached
            )

            return response
        }

        context.logger.debug(
            "Cache miss for rules generation",
            metadata: [
                "game_title": .string(sanitizedGameTitle),
                "cache_key": .string(cacheKey),
                "request_id": .string(context.requestID),
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

            Respond ONLY in valid JSON WITHOUT any markdown formatting using this structure:
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
            rulesResponse = try await llmService.generate(input: combinedPrompt)
        } catch {
            context.logger.error(
                "LLM service error during rules generation",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedGameTitle),
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                ])
            throw ContentError.externalServiceFailedToRespond
        }

        // SECURITY FIX: Validate AI response before returning using validation service
        do {
            let validatedResponse = try aiResponseValidator.validateRulesSummaryResponse(
                rulesResponse,
                gameTitle: sanitizedGameTitle,
                clientIP: context.clientIP,
                logger: context.logger
            )
            let rulesBuffer = ByteBuffer(string: validatedResponse)
            let rulesSummary = try JSONDecoder().decode(
                RulesSummary.Response.self, from: rulesBuffer)

            // PERFORMANCE OPTIMIZATION: Cache successful response
            await aiCache.set(
                key: cacheKey,
                value: validatedResponse,
                ttl: cacheConfiguration.rulesGenerationTTL
            )

            // Log successful generation and caching
            context.logger.info(
                "AI rules generation completed successfully",
                metadata: [
                    "game_title": .string(sanitizedGameTitle),
                    "confidence": .string("\(rulesSummary.confidence)"),
                    "cached": .string("true"),
                    "cache_key": .string(cacheKey),
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                ])

            let response = Response(
                rulesSummary: rulesSummary,
                processedGameTitle: rulesSummary.title,
                generatedAt: Date.now,
                wasCached: wasCached
            )

            return response
        } catch {
            context.logger.error(
                "AI response validation failed for rules generation",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedGameTitle),
                    "response_length": .string("\(rulesResponse.count)"),
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                ])
            throw ContentError.externalServiceFailedToRespond
        }
    }
}

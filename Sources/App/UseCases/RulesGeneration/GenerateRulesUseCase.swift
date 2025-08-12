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
    
    /// Domain service for rules generation and orchestration
    private let rulesOrchestrationService: RulesOrchestrationService
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
        rulesOrchestrationService: RulesOrchestrationService,
        aiInputValidator: AIInputValidatorServiceInterface,
        cacheKeyGenerator: CacheKeyGeneratorServiceInterface,
        aiCache: AICacheServiceInterface,
        llmService: LLMService,
        aiResponseValidator: AIResponseValidationService,
        cacheConfiguration: CacheConfig
    ) {
        self.rulesOrchestrationService = rulesOrchestrationService
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
    /// 2. Delegates to RulesOrchestrationService for core business logic
    /// 3. Handles input sanitization and validation transparently
    /// 4. Manages caching and performance optimization
    /// 5. Returns structured response with comprehensive metadata
    ///
    /// The use case abstracts away the complexity of title validation, AI model
    /// interaction, prompt engineering, response validation, and caching while
    /// providing a clean interface for controllers and other consumers.
    ///
    /// ## Error Handling
    /// - Propagates AIValidationError for invalid or malicious game titles
    /// - Propagates ValidationError for sanitization failures
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
        // Validate input parameters
        guard !request.gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Game title cannot be empty")
        }
        
        // Check for reasonable title length
        guard request.gameTitle.count <= 200 else {
            throw Abort(.badRequest, reason: "Game title too long (max 200 characters)")
        }
        
        // Delegate to domain service for core business logic
        // The service handles title sanitization, validation, AI generation,
        // response validation, caching, and all security concerns
        let rulesSummary = try await rulesOrchestrationService.generateRules(
            gameTitle: request.gameTitle,
            context: request.context,
            aiInputValidator: aiInputValidator,
            cacheKeyGenerator: cacheKeyGenerator,
            aiCache: aiCache,
            llmService: llmService,
            aiResponseValidator: aiResponseValidator,
            cacheConfiguration: cacheConfiguration
        )
        
        // Create structured response with metadata
        let response = Response(
            rulesSummary: rulesSummary,
            processedGameTitle: rulesSummary.title, // Use the title from AI response
            generatedAt: Date.now,
            wasCached: false // Cache information is abstracted by the service
        )
        
        request.context.logger.info("GenerateRulesUseCase completed successfully", metadata: [
            "original_title": .string(request.gameTitle),
            "processed_title": .string(response.processedGameTitle),
            "confidence": .string("\(rulesSummary.confidence)"),
            "client_ip": .string(request.context.clientIP),
            "request_id": .string(request.context.requestID)
        ])
        
        return response
    }
}
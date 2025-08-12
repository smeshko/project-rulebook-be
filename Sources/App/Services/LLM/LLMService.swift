import Vapor

/// Protocol defining the interface for Large Language Model service integrations.
///
/// This service provides a unified interface for AI text generation and image analysis
/// capabilities, currently implemented using OpenAI's API. The service includes
/// built-in retry logic, error handling, and performance optimizations.
///
/// ## Key Features
/// - Text generation with configurable parameters
/// - Image analysis and recognition capabilities  
/// - Automatic retry logic with exponential backoff
/// - JSON mode support for structured responses
/// - Request-specific service instances for proper dependency injection
///
/// ## Security Considerations
/// - All inputs are validated and sanitized before processing
/// - Responses are validated for security threats before returning
/// - API keys are securely managed through configuration service
/// - Rate limiting is enforced at the middleware level
///
/// ## Performance Optimizations
/// - Responses are cached to reduce API costs by up to 80%
/// - Configurable temperature and token limits for cost control
/// - Efficient retry logic with configurable backoff strategies
protocol LLMService {
    
    /// Generates text using default optimized parameters.
    ///
    /// This is a convenience method that uses the most cost-effective settings:
    /// - Model: gpt-4o-mini
    /// - Temperature: 0 (deterministic)
    /// - Max tokens: 1000
    /// - JSON mode: enabled
    ///
    /// - Parameter input: The text prompt for generation
    /// - Returns: Generated text response
    /// - Throws: ``OpenAIError`` for API-related failures, ``AIValidationError`` for input validation failures
    ///
    /// ## Usage
    /// ```swift
    /// let response = try await request.services.llm.generate(input: "Generate game rules for Chess")
    /// ```
    func generate(input: String) async throws -> String
    
    /// Generates text with full parameter control for advanced use cases.
    ///
    /// This method provides complete control over generation parameters, allowing
    /// fine-tuning for different use cases and cost optimization strategies.
    ///
    /// - Parameters:
    ///   - input: The text prompt for generation
    ///   - model: OpenAI model to use (default: "gpt-4o-mini" for cost efficiency)
    ///   - temperature: Randomness in generation (0.0-2.0, where 0 is deterministic)
    ///   - maxTokens: Maximum tokens in response (affects cost and response length)
    ///   - useJSONMode: Whether to enforce JSON format in response
    /// - Returns: Generated text response
    /// - Throws: ``OpenAIError`` for API-related failures, ``AIValidationError`` for input validation failures
    ///
    /// ## Parameter Guidelines
    /// - **Temperature**: Use 0 for consistent results, 0.7 for creative content
    /// - **Max Tokens**: Typical values: 500 (short), 1000 (medium), 2000 (long)
    /// - **JSON Mode**: Enable when expecting structured data responses
    ///
    /// ## Usage
    /// ```swift
    /// let response = try await request.services.llm.generateOptimized(
    ///     input: prompt,
    ///     model: "gpt-4o-mini",
    ///     temperature: 0.0,
    ///     maxTokens: 1500,
    ///     useJSONMode: true
    /// )
    /// ```
    func generateOptimized(
        input: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        useJSONMode: Bool
    ) async throws -> String
    
    /// Analyzes images using AI vision capabilities.
    ///
    /// This method processes images (game box photos, component images, etc.) and
    /// generates structured analysis based on the provided prompt. Commonly used
    /// for board game box recognition and component identification.
    ///
    /// - Parameters:
    ///   - imageData: Base64-encoded image data with data URL prefix (e.g., "data:image/jpeg;base64,...")
    ///   - prompt: Analysis instructions and expected response format
    ///   - model: Vision-capable model to use (default: "gpt-4o-mini")
    ///   - temperature: Randomness in analysis (typically 0 for consistent recognition)
    ///   - maxTokens: Maximum tokens in response (affects analysis detail level)
    ///   - useJSONMode: Whether to enforce JSON format in response (recommended)
    /// - Returns: Structured analysis response
    /// - Throws: ``OpenAIError`` for API failures, ``AIValidationError`` for invalid image data
    ///
    /// ## Image Requirements
    /// - Supported formats: JPEG, PNG, GIF, WebP
    /// - Maximum size: 10MB
    /// - Must be provided as data URL with proper MIME type
    ///
    /// ## Usage
    /// ```swift
    /// let analysis = try await request.services.llm.analyzeImage(
    ///     imageData: "data:image/jpeg;base64,/9j/4AAQSkZJRgABA...",
    ///     prompt: "Identify the board game in this image and return JSON with title and confidence",
    ///     model: "gpt-4o-mini",
    ///     temperature: 0.0,
    ///     maxTokens: 1000,
    ///     useJSONMode: true
    /// )
    /// ```
    func analyzeImage(
        imageData: String,
        prompt: String,
        model: String,
        temperature: Double,
        maxTokens: Int,
        useJSONMode: Bool
    ) async throws -> String

    /// Returns a service instance configured for the specific request context.
    ///
    /// This method is part of the service pattern used throughout the application,
    /// ensuring that services have access to request-specific context and logging.
    ///
    /// - Parameter request: The current request context
    /// - Returns: A service instance configured for the request
    func `for`(_ request: Request) -> LLMService
}

extension Application.Services {
    var llm: Application.Service<LLMService> {
        .init(application: application)
    }
}

extension Request.Services {
    var llm: LLMService {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.serviceCache.llmService.for(request)
    }
}

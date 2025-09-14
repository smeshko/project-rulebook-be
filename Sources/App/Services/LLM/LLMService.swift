import Vapor

/// Protocol defining the interface for Large Language Model service integrations.
///
/// This service provides a unified interface for AI text generation and image analysis
/// capabilities, supporting multiple Large Language Model (LLM) providers.
/// The service includes built-in retry logic, error handling, and performance
/// optimizations to ensure reliable and efficient AI interactions across different providers.
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
    /// - Default model: determined by current LLM provider configuration
    /// - Temperature: 0 (deterministic)
    /// - Max tokens: 1000
    /// - JSON mode: enabled
    ///
    /// - Parameter input: The text prompt for generation
    /// - Returns: Generated text response
    /// - Throws: Provider-specific API errors, validation errors for input processing
    ///
    /// ## Usage
    /// ```swift
    /// let response = try await request.services.llm.generate(input: "Generate game rules for Chess")
    /// ```
    func generate(input: String) async throws -> String
    
    /// Analyzes images using AI vision capabilities.
    ///
    /// This method processes images (game box photos, component images, etc.) and
    /// generates structured analysis based on the provided prompt. Commonly used
    /// for board game box recognition and component identification.
    ///
    /// - Parameters:
    ///   - imageData: Base64-encoded image data with data URL prefix (e.g., "data:image/jpeg;base64,...")
    ///   - prompt: Analysis instructions and expected response format
    /// - Returns: Structured analysis response
    /// - Throws: Provider-specific API errors, validation errors for image processing
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
    ///     prompt: "Identify the board game in this image and return JSON with title and confidence"
    /// )
    /// ```
    func analyzeImage(
        imageData: String,
        prompt: String
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

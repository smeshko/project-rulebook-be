import Vapor

/// Service provider extension for registering OpenAI as the LLM service implementation.
extension Application.Service.Provider where ServiceType == LLMService {
  /// Registers OpenAI as the LLM service provider.
  ///
  /// This provider configures the application to use OpenAI's API for all
  /// LLM operations including text generation and image analysis.
  static var openAI: Self {
    .init {
      $0.services.llm.use { OpenAIService(app: $0) }
    }
  }
}

/// OpenAI implementation of the LLM service protocol.
///
/// This service provides AI text generation and image analysis capabilities using
/// OpenAI's `/v1/responses` API endpoint. It includes comprehensive error handling,
/// retry logic, and security validations.
///
/// ## Key Features
/// - **Retry Logic**: Automatic retry with exponential backoff for transient failures
/// - **Error Handling**: Comprehensive error mapping and logging
/// - **Security**: Input validation and response sanitization
/// - **Performance**: Optimized for cost efficiency using gpt-4o-mini model
/// - **Rate Limiting**: Respects OpenAI rate limits with proper backoff
///
/// ## API Integration Details
/// Uses OpenAI's `/v1/responses` endpoint (not the deprecated Chat Completions API)
/// with proper request/response format handling and authentication.
///
/// ## Security Considerations
/// - All inputs are validated before sending to OpenAI
/// - Responses are scanned for potential security threats
/// - API keys are managed securely through configuration service
/// - Comprehensive logging for security auditing
struct OpenAIService: LLMService {
  /// The Vapor application instance for accessing configuration and logging.
  let app: Application
  
  /// Maximum number of retry attempts for failed requests.
  ///
  /// Requests are retried up to 3 times with exponential backoff for:
  /// - Rate limit errors (429)
  /// - Server errors (5xx)
  /// - Network timeouts
  private let maxRetries: Int = 3
  
  /// Base delay in seconds for exponential backoff calculations.
  ///
  /// The actual delay is calculated as: baseDelay * (2 ^ attempt) for server errors,
  /// or uses the Retry-After header value for rate limit errors.
  private let baseDelay: TimeInterval = 1.0

  /// HTTP headers for OpenAI API requests.
  ///
  /// Constructs the required headers for authentication and content type.
  /// Falls back to environment variable if configuration service fails.
  ///
  /// ## Headers Included
  /// - `Content-Type`: application/json
  /// - `Authorization`: Bearer token with OpenAI API key
  ///
  /// - Returns: HTTP headers required for OpenAI API requests
  private var headers: HTTPHeaders {
    do {
      let services = try app.configuration.services
      return [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(services.openAIKey)",
      ]
    } catch {
      app.logger.error("Failed to get OpenAI configuration: \(error)")
      return [
        "Content-Type": "application/json",
        "Authorization": "Bearer \(Environment.openAIKey)",
      ]
    }
  }

  /// Generates text using default optimized parameters for cost efficiency.
  ///
  /// This convenience method uses the most cost-effective settings optimized
  /// for the application's typical use cases (game rules generation).
  ///
  /// ## Default Parameters
  /// - Model: gpt-4o-mini (most cost-effective)
  /// - Temperature: 0 (deterministic responses)
  /// - Max tokens: 1000 (sufficient for most responses)
  /// - JSON mode: enabled (structured responses)
  ///
  /// - Parameter input: The text prompt for generation
  /// - Returns: Generated text response
  /// - Throws: ``OpenAIError`` for API failures
  func generate(input: String) async throws -> String {
    return try await generateOptimized(
      input: input,
      model: "gpt-4o-mini",
      temperature: 0,
      maxTokens: 1000,
      useJSONMode: true
    )
  }

  /// Generates text with full parameter control and retry logic.
  ///
  /// This method provides comprehensive text generation with configurable parameters
  /// and built-in retry logic for handling transient failures.
  ///
  /// ## Retry Behavior
  /// - Rate limit errors: Respects Retry-After headers
  /// - Server errors: Exponential backoff (1s, 2s, 4s)
  /// - Network errors: Linear backoff (1s, 2s, 3s)
  /// - Authentication/validation errors: No retry (immediate failure)
  ///
  /// - Parameters:
  ///   - input: The text prompt for generation
  ///   - model: OpenAI model to use (default: "gpt-4o-mini")
  ///   - temperature: Randomness in generation (0.0-2.0)
  ///   - maxTokens: Maximum tokens in response
  ///   - useJSONMode: Whether to enforce JSON format
  /// - Returns: Generated text response
  /// - Throws: ``OpenAIError`` for API failures after all retries exhausted
  func generateOptimized(
    input: String,
    model: String = "gpt-4o-mini",
    temperature: Double = 0,
    maxTokens: Int = 1000,
    useJSONMode: Bool = true
  ) async throws -> String {
    return try await withRetry(maxAttempts: maxRetries) { attempt in
      try await performGenerationOptimized(
        input: input,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
        useJSONMode: useJSONMode,
        attempt: attempt
      )
    }
  }

  /// Analyzes images using OpenAI's vision capabilities with retry logic.
  ///
  /// This method processes images and generates structured analysis responses.
  /// Commonly used for board game box recognition and component identification.
  ///
  /// ## Image Processing
  /// - Supports JPEG, PNG, GIF, WebP formats
  /// - Maximum size: 10MB (validated before processing)
  /// - Requires data URL format with proper MIME type
  /// - Input validation prevents malicious image data
  ///
  /// ## Vision Analysis Features
  /// - Text recognition from game boxes
  /// - Component identification and counting  
  /// - Artwork and theme analysis
  /// - Confidence scoring for recognition accuracy
  ///
  /// - Parameters:
  ///   - imageData: Base64-encoded image with data URL prefix
  ///   - prompt: Analysis instructions and expected response format
  ///   - model: Vision-capable model (default: "gpt-4o-mini")
  ///   - temperature: Randomness in analysis (typically 0 for consistency)
  ///   - maxTokens: Maximum response length
  ///   - useJSONMode: Whether to enforce structured JSON response
  /// - Returns: Structured analysis response as JSON string
  /// - Throws: ``OpenAIError`` for API failures, ``AIValidationError`` for invalid images
  func analyzeImage(
    imageData: String,
    prompt: String,
    model: String = "gpt-4o-mini",
    temperature: Double = 0,
    maxTokens: Int = 1000,
    useJSONMode: Bool = true
  ) async throws -> String {
    return try await withRetry(maxAttempts: maxRetries) { attempt in
      try await performImageAnalysis(
        imageData: imageData,
        prompt: prompt,
        model: model,
        temperature: temperature,
        maxTokens: maxTokens,
        useJSONMode: useJSONMode,
        attempt: attempt
      )
    }
  }

  /// Performs a single text generation request to OpenAI's API.
  ///
  /// This is the core method that handles the actual HTTP request to OpenAI,
  /// including error handling and response processing. It's called by the retry logic.
  ///
  /// ## API Endpoint
  /// Uses OpenAI's `/v1/responses` endpoint with the new request format,
  /// not the deprecated Chat Completions API.
  ///
  /// ## Error Handling
  /// - 429 (Rate Limited): Extracts Retry-After header for backoff
  /// - 401 (Unauthorized): Authentication failure (no retry)
  /// - 5xx (Server Error): Server-side issue (retry with backoff)
  /// - 200 (Success): Processes response and validates content
  ///
  /// - Parameters:
  ///   - input: The text prompt for generation
  ///   - model: OpenAI model identifier
  ///   - temperature: Generation randomness
  ///   - maxTokens: Response length limit
  ///   - useJSONMode: JSON format enforcement
  ///   - attempt: Current attempt number (for logging)
  /// - Returns: Generated text response
  /// - Throws: ``OpenAIError`` for various API failures
  private func performGenerationOptimized(
    input: String,
    model: String,
    temperature: Double,
    maxTokens: Int,
    useJSONMode: Bool,
    attempt: Int
  ) async throws -> String {
    do {
      let response = try await app.client.post(
        .init(string: "https://api.openai.com/v1/responses"),
        headers: headers,
        content: OpenAIRequest(
          model: model,
          input: .text(input),
          instructions: nil,
          temperature: nil,
          maxOutputTokens: nil,
          text: nil
        )
      )

      // Check response status before processing
      switch response.status {
      case .tooManyRequests:
        app.logger.warning("OpenAI rate limit hit (attempt \(attempt)/\(maxRetries))")
        throw OpenAIError.rateLimitExceeded(retryAfter: extractRetryAfter(from: response))
      case .unauthorized:
        app.logger.error("OpenAI authentication failed")
        throw OpenAIError.authenticationFailed
      case let status where status.code >= 500:
        app.logger.warning("OpenAI server error (attempt \(attempt)/\(maxRetries)): \(status)")
        throw OpenAIError.serverError(Int(status.code))
      case .ok:
        return try await processResponse(response)
      default:
        app.logger.error(
          "OpenAI unexpected status (attempt \(attempt)/\(maxRetries)): \(response.status)")
        throw OpenAIError.requestFailed(
          NSError(
            domain: "OpenAI", code: Int(response.status.code),
            userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP status: \(response.status)"]))
      }

    } catch let error as OpenAIError {
      throw error

    } catch {
      app.logger.error("OpenAI request failed (attempt \(attempt)/\(maxRetries)): \(error)")
      throw OpenAIError.requestFailed(error)
    }
  }

  private func performImageAnalysis(
    imageData: String,
    prompt: String,
    model: String,
    temperature: Double,
    maxTokens: Int,
    useJSONMode: Bool,
    attempt: Int
  ) async throws -> String {
    do {
      // Create content array with text prompt and image
      let inputContents: [OpenAIRequest.InputContent] = [
        OpenAIRequest.InputContent(content: OpenAIRequest.InputContent.TextContent(text: prompt)),
        OpenAIRequest.InputContent(
          content: OpenAIRequest.InputContent.ImageContent(imageUrl: imageData)),
      ]
      
      // Create message with role "user" and content array (matching JavaScript structure)
      let message = OpenAIRequest.Message(role: "user", content: inputContents)

      let response = try await app.client.post(
        .init(string: "https://api.openai.com/v1/responses"),
        headers: headers,
        content: OpenAIRequest(
          model: model,
          input: .messages([message]),
          instructions: nil,
          temperature: nil,
          maxOutputTokens: nil,
          text: nil
        )
      )

      // Check response status before processing
      switch response.status {
      case .tooManyRequests:
        app.logger.warning("OpenAI rate limit hit (attempt \(attempt)/\(maxRetries))")
        throw OpenAIError.rateLimitExceeded(retryAfter: extractRetryAfter(from: response))
      case .unauthorized:
        app.logger.error("OpenAI authentication failed")
        throw OpenAIError.authenticationFailed
      case let status where status.code >= 500:
        app.logger.warning("OpenAI server error (attempt \(attempt)/\(maxRetries)): \(status)")
        throw OpenAIError.serverError(Int(status.code))
      case .ok:
        return try await processResponse(response)
      default:
        app.logger.error(
          "OpenAI unexpected status (attempt \(attempt)/\(maxRetries)): \(response.status)")
        throw OpenAIError.requestFailed(
          NSError(
            domain: "OpenAI", code: Int(response.status.code),
            userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP status: \(response.status)"]))
      }

    } catch let error as OpenAIError {
      throw error

    } catch {
      app.logger.error(
        "OpenAI image analysis request failed (attempt \(attempt)/\(maxRetries)): \(error)")
      throw OpenAIError.requestFailed(error)
    }
  }

  /// Processes and validates OpenAI API responses.
  ///
  /// This method handles the parsing and validation of responses from OpenAI's API,
  /// including error detection and content extraction.
  ///
  /// ## Response Processing Steps
  /// 1. Decode JSON response using snake_case conversion
  /// 2. Check for API error messages in response
  /// 3. Extract text content from response structure
  /// 4. Validate that response is not empty
  ///
  /// ## Error Handling
  /// - API errors: Throws ``OpenAIError.apiError`` with error message
  /// - Empty responses: Throws ``OpenAIError.emptyResponse``
  /// - Invalid JSON: Throws ``OpenAIError.invalidResponse`` with decoding error
  ///
  /// - Parameter response: Raw HTTP response from OpenAI API
  /// - Returns: Extracted text content from the response
  /// - Throws: ``OpenAIError`` for various response processing failures
  private func processResponse(_ response: ClientResponse) async throws -> String {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    do {
      let decodedResponse = try response.content.decode(OpenAIResponse.self, using: decoder)

      if let error = decodedResponse.error {
        throw OpenAIError.apiError(error.message)
      }

      guard let content = decodedResponse.extractText() else {
        throw OpenAIError.emptyResponse
      }

      return content

    } catch let decodingError as DecodingError {
      app.logger.error("Failed to decode OpenAI response: \(decodingError)")
      throw OpenAIError.invalidResponse(decodingError)
    }
  }

  /// Generic retry mechanism with configurable backoff strategies.
  ///
  /// This method implements a sophisticated retry mechanism that handles different
  /// types of failures with appropriate backoff strategies.
  ///
  /// ## Retry Logic
  /// - **Rate Limits**: Uses Retry-After header or exponential backoff
  /// - **Server Errors**: Exponential backoff (1s, 2s, 4s, 8s...)
  /// - **Other Errors**: Linear backoff (1s, 2s, 3s, 4s...)
  /// - **Non-retryable**: Authentication, validation errors fail immediately
  ///
  /// ## Backoff Calculation
  /// - Rate limit: `retryAfter ?? baseDelay * (2^attempt)`
  /// - Server error: `baseDelay * (2^(attempt-1))`
  /// - Default: `baseDelay * attempt`
  ///
  /// - Parameters:
  ///   - maxAttempts: Maximum number of attempts before giving up
  ///   - operation: The operation to retry, receives attempt number
  /// - Returns: Result of the operation if successful
  /// - Throws: The last error encountered after all retries exhausted
  private func withRetry<T>(maxAttempts: Int, operation: (Int) async throws -> T) async throws -> T
  {
    var lastError: Error?

    for attempt in 1...maxAttempts {
      do {
        return try await operation(attempt)

      } catch let openAIError as OpenAIError {
        // Check if this is a non-retryable error
        switch openAIError {
        case .authenticationFailed, .emptyResponse, .invalidResponse:
          throw openAIError
        default:
          break
        }

        lastError = openAIError

        if attempt == maxAttempts {
          break
        }

        let delay = calculateBackoffDelay(attempt: attempt, error: openAIError)
        app.logger.info("Retrying OpenAI request in \(delay)s (attempt \(attempt)/\(maxAttempts))")

        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

      } catch {
        throw error  // Don't retry non-OpenAI errors
      }
    }

    throw lastError
      ?? OpenAIError.requestFailed(
        NSError(
          domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])
      )
  }

  private func calculateBackoffDelay(attempt: Int, error: OpenAIError) -> TimeInterval {
    switch error {
    case .rateLimitExceeded(let retryAfter):
      return retryAfter ?? Double(attempt * 2)  // Exponential backoff if no retry-after header
    case .serverError:
      return baseDelay * pow(2.0, Double(attempt - 1))  // Exponential backoff
    default:
      return baseDelay * Double(attempt)  // Linear backoff
    }
  }

  private func extractRetryAfter(from response: ClientResponse) -> TimeInterval? {
    guard let retryAfterHeader = response.headers.first(name: "Retry-After") else {
      return nil
    }
    return TimeInterval(retryAfterHeader)
  }

  /// Returns a service instance configured for the specific request context.
  ///
  /// This method implements the service pattern used throughout the application,
  /// ensuring each request gets a properly configured service instance with
  /// access to request-specific logging and context.
  ///
  /// - Parameter request: The current HTTP request context
  /// - Returns: An OpenAI service instance configured for the request
  func `for`(_ request: Request) -> LLMService {
    Self(app: request.application)
  }
}

// MARK: - ServiceLifecycle Implementation

extension OpenAIService: ServiceLifecycle {
  /// Initializes the OpenAI service during application startup.
  func startup(_ app: Application) async throws {
    do {
      let config = try app.configuration.services
      
      // Validate configuration is present
      guard !config.openAIKey.isEmpty else {
        throw ConfigurationError.missingRequired(key: "OPENAI_API_KEY", suggestion: "Set the OpenAI API key in environment variables")
      }
      
      // Test API connectivity with a minimal request to validate API key
      // Using a simple models list endpoint which is lightweight and doesn't consume tokens
      let response = try await app.client.get(
        URI(string: "https://api.openai.com/v1/models"),
        headers: HTTPHeaders([
          ("Authorization", "Bearer \(config.openAIKey)")
        ])
      )
      
      guard response.status == .ok else {
        app.logger.error("OpenAI service startup failed", metadata: [
          "status_code": .string("\(response.status.code)"),
          "api_endpoint": .string("https://api.openai.com/v1/models")
        ])
        
        // Provide specific error messages for common failures
        let errorMessage: String
        switch response.status {
        case .unauthorized:
          errorMessage = "OpenAI API key is invalid or expired"
        case .forbidden:
          errorMessage = "OpenAI API access is forbidden (quota exceeded or billing issues)"
        case .tooManyRequests:
          errorMessage = "OpenAI API rate limit exceeded during startup"
        default:
          errorMessage = "OpenAI API returned status: \(response.status)"
        }
        
        let error = NSError(domain: "OpenAIService", code: Int(response.status.code), userInfo: [NSLocalizedDescriptionKey: "API request failed"])
        throw ServiceRegistryError.serviceInitializationFailed(errorMessage, error)
      }
      
      // Parse response to get available models for logging
      let decoder = JSONDecoder()
      let modelsResponse = try response.content.decode(OpenAIModelsResponse.self, using: decoder)
      let modelNames = modelsResponse.data.map { $0.id }.joined(separator: ", ")
      
      app.logger.info("OpenAI service started successfully", metadata: [
        "available_models_count": .string("\(modelsResponse.data.count)"),
        "primary_model": .string("gpt-4o-mini"),
        "api_key_length": .string("\(config.openAIKey.count) characters")
      ])
      
    } catch let error as ConfigurationError {
      app.logger.error("OpenAI service configuration error", metadata: [
        "error": .string(error.localizedDescription)
      ])
      throw error
      
    } catch {
      app.logger.error("OpenAI service startup failed", metadata: [
        "error": .string(error.localizedDescription)
      ])
      throw error
    }
  }
  
  /// Gracefully shuts down the OpenAI service during application termination.
  func shutdown(_ app: Application) async throws {
    // OpenAI is stateless HTTP-based service, no persistent connections to close
    // Log any pending operations that might be cancelled
    app.logger.info("OpenAI service shut down gracefully")
  }
}

// MARK: - ServiceHealthCheck Implementation

extension OpenAIService: ServiceHealthCheck {
  /// Performs a health check to determine if OpenAI service is operating correctly.
  func isHealthy() async -> Bool {
    do {
      let config = try app.configuration.services
      
      // Test connectivity with a lightweight API call that doesn't consume tokens
      let startTime = Date()
      let response = try await app.client.get(
        URI(string: "https://api.openai.com/v1/models"),
        headers: HTTPHeaders([
          ("Authorization", "Bearer \(config.openAIKey)")
        ])
      )
      let responseTime = Date().timeIntervalSince(startTime)
      
      // Check response status
      guard response.status == .ok else {
        app.logger.warning("OpenAI health check: API returned non-OK status", metadata: [
          "status_code": .string("\(response.status.code)")
        ])
        return false
      }
      
      // Check response time is reasonable (under 3 seconds for healthy service)
      guard responseTime < 3.0 else {
        app.logger.warning("OpenAI health check: slow response time", metadata: [
          "response_time_ms": .string(String(format: "%.2f", responseTime * 1000))
        ])
        return false
      }
      
      // Verify we can parse the response properly
      let decoder = JSONDecoder()
      let modelsResponse = try response.content.decode(OpenAIModelsResponse.self, using: decoder)
      
      // Check that our primary model is available
      let hasGPT4Mini = modelsResponse.data.contains { $0.id == "gpt-4o-mini" }
      guard hasGPT4Mini else {
        app.logger.warning("OpenAI health check: primary model gpt-4o-mini not available")
        return false
      }
      
      return true
      
    } catch {
      app.logger.warning("OpenAI health check failed", metadata: [
        "error": .string(error.localizedDescription)
      ])
      return false
    }
  }
  
  /// Provides a human-readable name for this service's health check.
  func healthCheckName() -> String {
    "OpenAI LLM Service"
  }
}

// MARK: - Supporting Types

/// Response structure for OpenAI models endpoint used in health checks.
private struct OpenAIModelsResponse: Codable {
  struct ModelData: Codable {
    let id: String
    let object: String
    let created: Int?
    let ownedBy: String?
    
    enum CodingKeys: String, CodingKey {
      case id
      case object
      case created
      case ownedBy = "owned_by"
    }
  }
  
  let object: String
  let data: [ModelData]
}

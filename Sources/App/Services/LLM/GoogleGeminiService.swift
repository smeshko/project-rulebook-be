import Vapor

// MARK: - Service Provider Extension

extension Application.Service.Provider where ServiceType == LLMService {
    /// Registers Google Gemini as the LLM service provider.
    static var googleGemini: Self {
        .init { app in
            app.services.llm.use { GoogleGeminiService(app: $0, logger: $0.logger) }
        }
    }
}

// MARK: - GoogleGeminiService

/// Google Gemini implementation of the LLM service protocol.
///
/// Implements text generation and image analysis using the Gemini
/// `generateContent` API with proper retry and error handling.
///
/// ## Key Features
/// - Uses Gemini 2.5 Pro model for text and image generation
/// - Handles multi-part content requests (text + optional image)
/// - Configurable retry logic for rate limits and server errors
/// - Comprehensive error handling specific to Gemini API
/// - Supports base64-encoded image data with MIME type detection
///
/// ## API Integration
/// - Endpoint: generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro
/// - Authentication: API key via x-goog-api-key header
/// - Retry strategy: Exponential backoff for rate limits
///
/// ## Error Handling
/// - Maps Gemini-specific errors to standardized error types
/// - Provides detailed error context for debugging
/// - Handles authentication, rate limit, and server errors
struct GoogleGeminiService: LLMService {
    let app: Application
    let logger: Logger

    private let maxRetries: Int = 3
    private let baseDelay: TimeInterval = 1.0

    private var headers: HTTPHeaders {
        do {
            let config = try app.configuration.services
            return [
                "x-goog-api-key": config.geminiApiKey,
                "Content-Type": "application/json",
            ]
        } catch {
            logger.error("Failed to get Gemini configuration: \(error)")
            // Best-effort fallback
            let apiKey = Environment.get("GEMINI_API_KEY") ?? ""
            return [
                "x-goog-api-key": apiKey,
                "Content-Type": "application/json",
            ]
        }
    }

    // MARK: - LLMService
    func generate(input: String) async throws -> String {
        let url = URI(
            string:
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
        )

        let requestBody = GeminiRequest(
            contents: [
                .init(parts: [
                    .init(text: input)
                ])
            ],
            tools: nil
        )

        return try await withRetry(maxAttempts: maxRetries) { attempt in
            do {
                let response = try await app.client.post(
                    url, headers: headers, content: requestBody)
                return try await processResponse(response)
            } catch let error as GeminiError {
                throw error
            } catch {
                logger.error(
                    "Gemini request failed (attempt \(attempt)/\(maxRetries)): \(error)")
                throw GeminiError.requestFailed(error)
            }
        }
    }

    func analyzeImage(
        imageData: String,
        prompt: String
    ) async throws -> String {
        let url = URI(
            string:
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
        )

        let (mime, base64Data) = try parseDataURL(imageData)

        let parts: [GeminiRequest.Part] = [
            .init(inlineData: .init(mimeType: mime, data: base64Data)),
            .init(text: prompt),
        ]

        let requestBody = GeminiRequest(contents: [.init(parts: parts)], tools: nil)

        return try await withRetry(maxAttempts: maxRetries) { attempt in
            do {
                let response = try await app.client.post(
                    url, headers: headers, content: requestBody)
                return try await processResponse(response)
            } catch let error as GeminiError {
                throw error
            } catch {
                logger.error(
                    "Gemini image analysis failed (attempt \(attempt)/\(maxRetries)): \(error)")
                throw GeminiError.requestFailed(error)
            }
        }
    }

    func `for`(_ request: Request) -> LLMService {
        Self(app: request.application, logger: request.logger)
    }

    // MARK: - Private helpers

    private func parseDataURL(_ dataURL: String) throws -> (mime: String, base64: String) {
        // Expected format: data:<mime>;base64,<data>
        guard dataURL.starts(with: "data:") else {
            throw GeminiError.invalidRequest("Image data must be a data URL with base64 encoding")
        }
        guard let commaIndex = dataURL.firstIndex(of: ",") else {
            throw GeminiError.invalidRequest("Invalid data URL format")
        }
        let meta = String(dataURL[dataURL.startIndex..<commaIndex])  // e.g., data:image/jpeg;base64
        let base64 = String(dataURL[dataURL.index(after: commaIndex)...])

        let mimePart = meta.replacingOccurrences(of: "data:", with: "")
        let mime = mimePart.components(separatedBy: ";").first ?? "image/jpeg"
        return (mime, base64)
    }

    private func processResponse(_ response: ClientResponse) async throws -> String {
        switch response.status {
        case .tooManyRequests:
            throw GeminiError.rateLimitExceeded(retryAfter: extractRetryAfter(from: response))
        case .unauthorized, .forbidden:
            throw GeminiError.authenticationFailed
        case let status where status.code >= 500:
            throw GeminiError.serverError(Int(status.code))
        default:
            break
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let decoded = try response.content.decode(GeminiResponse.self, using: decoder)
            guard let text = decoded.extractText(), !text.isEmpty else {
                throw GeminiError.emptyResponse
            }
            return text
        } catch let decoding as DecodingError {
            logger.error("Failed to decode Gemini response: \(decoding)")
            throw GeminiError.invalidResponse(decoding)
        }
    }

    private func extractRetryAfter(from response: ClientResponse) -> TimeInterval? {
        if let value = response.headers.first(name: "Retry-After"),
            let seconds = TimeInterval(value)
        {
            return seconds
        }
        return nil
    }

    // Simple retry helper inspired by OpenAIService
    private func withRetry<T>(
        maxAttempts: Int, operation: @Sendable @escaping (_ attempt: Int) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do { return try await operation(attempt) } catch {
                lastError = error

                // Determine delay based on error type
                var delay: TimeInterval = baseDelay
                if case let GeminiError.rateLimitExceeded(retryAfter) = error {
                    delay = retryAfter ?? baseDelay * pow(2, Double(attempt - 1))
                } else if case GeminiError.serverError = error {
                    delay = baseDelay * Double(attempt)
                } else if case GeminiError.authenticationFailed = error {
                    break  // do not retry
                }

                if attempt < maxAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            }
        }
        throw lastError ?? GeminiError.requestFailed(NSError(domain: "Gemini", code: -1))
    }
}


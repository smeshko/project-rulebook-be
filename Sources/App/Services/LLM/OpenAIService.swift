import Vapor

extension Application.Service.Provider where ServiceType == LLMService {
    static var openAI: Self {
        .init {
            $0.services.llm.use { OpenAIService(app: $0) }
        }
    }
}

struct OpenAIService: LLMService {
    let app: Application
    private let maxRetries: Int = 3
    private let baseDelay: TimeInterval = 1.0
    
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
    
    func generate(input: [OpenAIRequest.Message]) async throws -> String {
        return try await withRetry(maxAttempts: maxRetries) { attempt in
            try await performGeneration(input: input, attempt: attempt)
        }
    }
    
    private func performGeneration(input: [OpenAIRequest.Message], attempt: Int) async throws -> String {
        do {
            let response = try await app.client.post(
                .init(string: "https://api.openai.com/v1/responses"),
                headers: headers,
                content: OpenAIRequest(
                    model: "gpt-4.1",
                    input: input
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
                app.logger.error("OpenAI unexpected status (attempt \(attempt)/\(maxRetries)): \(response.status)")
                throw OpenAIError.requestFailed(NSError(domain: "OpenAI", code: Int(response.status.code), userInfo: [NSLocalizedDescriptionKey: "Unexpected HTTP status: \(response.status)"]))
            }
            
        } catch let error as OpenAIError {
            throw error
            
        } catch {
            app.logger.error("OpenAI request failed (attempt \(attempt)/\(maxRetries)): \(error)")
            throw OpenAIError.requestFailed(error)
        }
    }
    
    private func processResponse(_ response: ClientResponse) async throws -> String {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let decodedResponse = try response.content.decode(OpenAIResponse.self, using: decoder)
            
            if let error = decodedResponse.error {
                throw OpenAIError.apiError(error)
            }
            
            guard let text = decodedResponse.output.first?.content.first?.text else {
                throw OpenAIError.emptyResponse
            }
            
            return text
            
        } catch let decodingError as DecodingError {
            app.logger.error("Failed to decode OpenAI response: \(decodingError)")
            throw OpenAIError.invalidResponse(decodingError)
        }
    }
    
    private func withRetry<T>(maxAttempts: Int, operation: (Int) async throws -> T) async throws -> T {
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
                throw error // Don't retry non-OpenAI errors
            }
        }
        
        throw lastError ?? OpenAIError.requestFailed(NSError(domain: "OpenAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"]))
    }
    
    private func calculateBackoffDelay(attempt: Int, error: OpenAIError) -> TimeInterval {
        switch error {
        case .rateLimitExceeded(let retryAfter):
            return retryAfter ?? Double(attempt * 2) // Exponential backoff if no retry-after header
        case .serverError:
            return baseDelay * pow(2.0, Double(attempt - 1)) // Exponential backoff
        default:
            return baseDelay * Double(attempt) // Linear backoff
        }
    }
    
    private func extractRetryAfter(from response: ClientResponse) -> TimeInterval? {
        guard let retryAfterHeader = response.headers.first(name: "Retry-After") else {
            return nil
        }
        return TimeInterval(retryAfterHeader)
    }
    
    func `for`(_ request: Request) -> LLMService {
        Self(app: request.application)
    }
}

enum OpenAIError: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case serverError(Int)
    case requestFailed(Error)
    case emptyResponse
    case invalidResponse(Error)
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "OpenAI authentication failed. Please check your API key."
        case .rateLimitExceeded(let retryAfter):
            if let delay = retryAfter {
                return "OpenAI rate limit exceeded. Retry after \(delay) seconds."
            } else {
                return "OpenAI rate limit exceeded. Please try again later."
            }
        case .serverError(let code):
            return "OpenAI server error (HTTP \(code)). Please try again later."
        case .requestFailed(let error):
            return "OpenAI request failed: \(error.localizedDescription)"
        case .emptyResponse:
            return "OpenAI returned an empty response."
        case .invalidResponse(let error):
            return "Invalid response from OpenAI: \(error.localizedDescription)"
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        }
    }
}

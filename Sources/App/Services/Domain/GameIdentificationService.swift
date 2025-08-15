import Foundation
import Vapor

/// Domain service for game identification operations using AI image analysis.
///
/// This service encapsulates the complex business logic for analyzing board game
/// box images to identify games and extract relevant information. It handles
/// image processing, AI model interaction, response validation, and caching
/// to provide reliable game identification capabilities.
///
/// ## Key Responsibilities
/// - **Image Data Processing**: Converts and validates image data for AI analysis
/// - **AI Model Integration**: Coordinates with LLM services for vision-based analysis
/// - **Response Validation**: Ensures AI responses meet security and quality standards
/// - **Performance Optimization**: Manages caching to reduce API costs and latency
/// - **Error Handling**: Provides comprehensive error handling and logging
///
/// ## Business Logic Encapsulation
/// This service extracts the following business logic from controllers:
/// - Image format detection and validation
/// - Cache key generation and management
/// - AI prompt construction and optimization
/// - Response parsing and validation
/// - Security scanning and content filtering
///
/// ## Dependencies
/// - **LLMService**: For AI-powered image analysis
/// - **AICacheServiceInterface**: For intelligent response caching
/// - **AIInputValidatorServiceInterface**: For security validation of image data
/// - **CacheKeyGeneratorServiceInterface**: For generating content-based cache keys
/// - **IPExtractorService**: For security logging and monitoring
protocol GameIdentificationService: Sendable {
    /// Analyzes a board game box image to identify the game and extract information.
    ///
    /// This method coordinates the complete game identification workflow, including
    /// image validation, cache lookup, AI analysis, response validation, and caching.
    ///
    /// - Parameters:
    ///   - imageData: Raw binary image data from the request
    ///   - context: Request context with client information and logger
    ///   - aiInputValidator: Service for validating AI inputs
    ///   - cacheKeyGenerator: Service for generating cache keys
    ///   - aiCache: Service for caching AI responses
    ///   - llmService: Service for LLM interactions
    ///   - aiResponseValidator: Service for validating AI responses
    ///   - cacheConfiguration: Cache configuration settings
    /// - Returns: Game identification results with confidence ratings
    /// - Throws: AIValidationError for invalid images, ContentError for AI failures
    func analyzeGameBox(
        imageData: Data,
        context: RequestContext,
        aiInputValidator: AIInputValidatorServiceInterface,
        cacheKeyGenerator: CacheKeyGeneratorServiceInterface,
        aiCache: AICacheServiceInterface,
        llmService: LLMService,
        aiResponseValidator: AIResponseValidationService,
        cacheConfiguration: CacheConfig
    ) async throws -> GameboxRecognition.Response
}

/// Production implementation of GameIdentificationService.
///
/// This implementation provides robust game identification capabilities with
/// comprehensive security validation, performance optimization, and error handling.
/// It uses the Vapor request to access services through the established service patterns.
final class DefaultGameIdentificationService: GameIdentificationService {
    
    // MARK: - Initialization
    
    /// Initializes the service with no dependencies - services are accessed via request.
    init() {}
    
    // MARK: - Service Implementation
    
    func analyzeGameBox(
        imageData: Data,
        context: RequestContext,
        aiInputValidator: AIInputValidatorServiceInterface,
        cacheKeyGenerator: CacheKeyGeneratorServiceInterface,
        aiCache: AICacheServiceInterface,
        llmService: LLMService,
        aiResponseValidator: AIResponseValidationService,
        cacheConfiguration: CacheConfig
    ) async throws -> GameboxRecognition.Response {
        
        context.logger.info("Game identification service initiated", metadata: [
            "client_ip": .string(context.clientIP),
            "image_size": .string("\(imageData.count) bytes"),
            "request_id": .string(context.requestID),
            "timestamp": .string(ISO8601DateFormatter().string(from: context.timestamp))
        ])
        
        // 1. Process and validate image data
        let dataURL = try processImageData(imageData, context: context, aiInputValidator: aiInputValidator)
        
        // 2. Check cache for existing results
        let cacheKey = cacheKeyGenerator.generateBoxPhotoKey(for: imageData, context: "box")
        
        if let cachedResponse = await aiCache.get(key: cacheKey) {
            context.logger.info("Cache hit for game identification", metadata: [
                "cache_key": .string(cacheKey),
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID)
            ])
            
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: cachedBuffer)
            return result
        }
        
        context.logger.debug("Cache miss for game identification", metadata: [
            "cache_key": .string(cacheKey),
            "request_id": .string(context.requestID)
        ])
        
        // 3. Generate AI analysis
        let response = try await performAIAnalysis(dataURL: dataURL, context: context, llmService: llmService)
        
        // 4. Validate and cache response
        let result = try await validateAndCacheResponse(
            response: response,
            cacheKey: cacheKey,
            context: context,
            aiCache: aiCache,
            aiResponseValidator: aiResponseValidator,
            cacheConfiguration: cacheConfiguration
        )
        
        context.logger.info("Game identification completed successfully", metadata: [
            "confidence": .string("\(result.confidence)"),
            "guessed_title": .string(result.guessedTitle),
            "cached": .string("true"),
            "cache_key": .string(cacheKey),
            "client_ip": .string(context.clientIP),
            "request_id": .string(context.requestID)
        ])
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Processes raw image data and validates it for AI analysis.
    private func processImageData(
        _ imageData: Data, 
        context: RequestContext, 
        aiInputValidator: AIInputValidatorServiceInterface
    ) throws -> String {
        // Convert binary image data to base64 with data URL prefix
        let base64String = imageData.base64EncodedString()
        
        // Validate image format by checking headers - reject invalid data
        let mimeType: String
        if imageData.count >= 4 {
            let header = imageData.prefix(4)
            if header.starts(with: [0xFF, 0xD8, 0xFF]) {
                mimeType = "image/jpeg"
            } else if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                mimeType = "image/png"
            } else if header.starts(with: [0x47, 0x49, 0x46]) {
                mimeType = "image/gif"
            } else if header.starts(with: [0x52, 0x49, 0x46, 0x46]) {
                // WebP format check (RIFF container)
                if imageData.count >= 12 {
                    let webpHeader = imageData.prefix(12)
                    if webpHeader[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
                        mimeType = "image/webp"
                    } else {
                        context.logger.warning("Invalid image format - unrecognized RIFF container", metadata: [
                            "client_ip": .string(context.clientIP),
                            "request_id": .string(context.requestID),
                            "data_size": .string("\(imageData.count) bytes")
                        ])
                        throw AIValidationError.invalidImageFormat
                    }
                } else {
                    context.logger.warning("Invalid image format - truncated RIFF header", metadata: [
                        "client_ip": .string(context.clientIP),
                        "request_id": .string(context.requestID),
                        "data_size": .string("\(imageData.count) bytes")
                    ])
                    throw AIValidationError.invalidImageFormat
                }
            } else {
                context.logger.warning("Invalid image format - unrecognized header", metadata: [
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                    "header_bytes": .string(Array(header).map { String(format: "%02X", $0) }.joined(separator: " ")),
                    "data_size": .string("\(imageData.count) bytes")
                ])
                throw AIValidationError.invalidImageFormat
            }
        } else {
            context.logger.warning("Invalid image format - insufficient data", metadata: [
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID),
                "data_size": .string("\(imageData.count) bytes")
            ])
            throw AIValidationError.invalidImageFormat
        }
        
        // Create data URL format for validation
        let dataURL = "data:\(mimeType);base64,\(base64String)"
        
        // Validate image data for security and compliance
        do {
            try aiInputValidator.validateImageData(dataURL)
        } catch let validationError as AIValidationError {
            context.logger.warning("Image validation failed", metadata: [
                "error": .string(validationError.description),
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID)
            ])
            throw validationError
        }
        
        return dataURL
    }
    
    /// Performs AI image analysis using the LLM service.
    private func performAIAnalysis(
        dataURL: String, 
        context: RequestContext, 
        llmService: LLMService
    ) async throws -> String {
        // Construct optimized prompt for game identification
        let systemPrompt = """
        You are an expert board game identification assistant. Analyze the game box image carefully.
        
        Follow this process:
        1. Examine all visible text on the box (title, publisher, descriptions)
        2. Note visual indicators (artwork style, component images, age ratings)
        3. Consider franchise/series if applicable
        4. Assess your confidence based on text clarity and distinctive features
        
        Return a JSON response with this exact structure:
        {
          "guessedTitle": "exact game title as shown on box",
          "confidence": 0-100,
          "alternativeTitles": ["list any subtitle variations or international names"],
          "keywordsDetected": ["all visible text elements", "publisher name", "player count", "age range"],
          "notes": "mention any uncertainties, image quality issues, or special observations"
        }
        
        Confidence guidelines:
        - 90-100: Title clearly visible and readable
        - 70-89: Title partially visible or slightly unclear
        - 50-69: Making educated guess based on artwork/components
        - Below 50: Very uncertain, image quality poor
        
        If text is unclear, mention it in notes. For franchise games, include the specific edition.
        """
        
        do {
            return try await llmService.analyzeImage(
                imageData: dataURL,
                prompt: systemPrompt,
                model: "gpt-4o-mini",
                temperature: 0,
                maxTokens: 1000,
                useJSONMode: true
            )
        } catch {
            context.logger.error("LLM service error during game identification", metadata: [
                "error": .string(error.localizedDescription),
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID)
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }
    
    /// Validates AI response and caches successful results.
    private func validateAndCacheResponse(
        response: String,
        cacheKey: String,
        context: RequestContext,
        aiCache: AICacheServiceInterface,
        aiResponseValidator: AIResponseValidationService,
        cacheConfiguration: CacheConfig
    ) async throws -> GameboxRecognition.Response {
        
        // Validate response format and content using the dedicated validation service
        let validatedResponse = try aiResponseValidator.validateGameboxRecognitionResponse(
            response, 
            clientIP: context.clientIP, 
            logger: context.logger
        )
        
        // Parse validated response
        let responseBuffer = ByteBuffer(string: validatedResponse)
        let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: responseBuffer)
        
        // Cache successful result
        await aiCache.set(
            key: cacheKey,
            value: validatedResponse,
            ttl: cacheConfiguration.imageAnalysisTTL
        )
        
        return result
    }
}
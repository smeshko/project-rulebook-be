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
    ///   - request: Vapor request for accessing services
    /// - Returns: Game identification results with confidence ratings
    /// - Throws: AIValidationError for invalid images, ContentError for AI failures
    func analyzeGameBox(
        imageData: Data,
        request: Request
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
        request: Request
    ) async throws -> GameboxRecognition.Response {
        
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let logger = request.logger
        
        logger.info("Game identification service initiated", metadata: [
            "client_ip": .string(clientIP),
            "image_size": .string("\(imageData.count) bytes"),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // 1. Process and validate image data
        let dataURL = try processImageData(imageData, request: request)
        
        // 2. Check cache for existing results
        let cacheKey = request.services.cacheKeyGenerator.generateBoxPhotoKey(for: imageData, context: "box")
        
        if let cachedResponse = await request.services.aiCache.get(key: cacheKey) {
            logger.info("Cache hit for game identification", metadata: [
                "cache_key": .string(cacheKey),
                "client_ip": .string(clientIP)
            ])
            
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: cachedBuffer)
            return result
        }
        
        logger.debug("Cache miss for game identification", metadata: [
            "cache_key": .string(cacheKey)
        ])
        
        // 3. Generate AI analysis
        let response = try await performAIAnalysis(dataURL: dataURL, request: request)
        
        // 4. Validate and cache response
        let result = try await validateAndCacheResponse(
            response: response,
            cacheKey: cacheKey,
            request: request
        )
        
        logger.info("Game identification completed successfully", metadata: [
            "confidence": .string("\(result.confidence)"),
            "guessed_title": .string(result.guessedTitle),
            "cached": .string("true"),
            "cache_key": .string(cacheKey),
            "client_ip": .string(clientIP)
        ])
        
        return result
    }
    
    // MARK: - Private Methods
    
    /// Processes raw image data and validates it for AI analysis.
    private func processImageData(_ imageData: Data, request: Request) throws -> String {
        // Convert binary image data to base64 with data URL prefix
        let base64String = imageData.base64EncodedString()
        
        // Determine MIME type from image data headers
        let mimeType: String
        if imageData.count >= 4 {
            let header = imageData.prefix(4)
            if header.starts(with: [0xFF, 0xD8, 0xFF]) {
                mimeType = "image/jpeg"
            } else if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                mimeType = "image/png"
            } else if header.starts(with: [0x47, 0x49, 0x46]) {
                mimeType = "image/gif"
            } else {
                mimeType = "image/png" // Default fallback
            }
        } else {
            mimeType = "image/png"
        }
        
        // Create data URL format for validation
        let dataURL = "data:\(mimeType);base64,\(base64String)"
        
        // Validate image data for security and compliance
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let logger = request.logger
        
        do {
            try request.services.aiInputValidator.validateImageData(dataURL)
        } catch let validationError as AIValidationError {
            logger.warning("Image validation failed", metadata: [
                "error": .string(validationError.description),
                "client_ip": .string(clientIP)
            ])
            throw validationError
        }
        
        return dataURL
    }
    
    /// Performs AI image analysis using the LLM service.
    private func performAIAnalysis(dataURL: String, request: Request) async throws -> String {
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
        
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let logger = request.logger
        
        do {
            return try await request.services.llm.analyzeImage(
                imageData: dataURL,
                prompt: systemPrompt,
                model: "gpt-4o-mini",
                temperature: 0,
                maxTokens: 1000,
                useJSONMode: true
            )
        } catch {
            logger.error("LLM service error during game identification", metadata: [
                "error": .string(error.localizedDescription),
                "client_ip": .string(clientIP)
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }
    
    /// Validates AI response and caches successful results.
    private func validateAndCacheResponse(
        response: String,
        cacheKey: String,
        request: Request
    ) async throws -> GameboxRecognition.Response {
        
        // Validate response format and content
        let validatedResponse = try validateResponse(response, request: request)
        
        // Parse validated response
        let responseBuffer = ByteBuffer(string: validatedResponse)
        let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: responseBuffer)
        
        // Cache successful result
        let cacheConfig = try request.application.configuration.cache
        await request.services.aiCache.set(
            key: cacheKey,
            value: validatedResponse,
            ttl: cacheConfig.imageAnalysisTTL
        )
        
        return result
    }
    
    /// Validates AI response for security and structural integrity.
    private func validateResponse(_ response: String, request: Request) throws -> String {
        
        let clientIP = request.services.ipExtractor.extractClientIP(from: request)
        let logger = request.logger
        // Check response size limits (prevent DoS)
        let maxResponseSize = 50_000 // 50KB max response
        guard response.count <= maxResponseSize else {
            logger.warning("AI response too large", metadata: [
                "size": .string("\(response.count)"),
                "client_ip": .string(clientIP)
            ])
            throw Abort(.payloadTooLarge, reason: "AI response too large")
        }
        
        // Check for minimum response size
        guard response.count >= 10 else {
            logger.warning("AI response too short", metadata: [
                "size": .string("\(response.count)"),
                "client_ip": .string(clientIP)
            ])
            throw Abort(.unprocessableEntity, reason: "AI response too short")
        }
        
        // Basic JSON structure validation
        guard response.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") &&
              response.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") else {
            logger.warning("AI response invalid JSON structure", metadata: [
                "client_ip": .string(clientIP)
            ])
            throw Abort(.unprocessableEntity, reason: "AI response is not valid JSON")
        }
        
        // Check for potential security threats
        let suspiciousPatterns = [
            "<script", "javascript:", "data:text/html", "eval(",
            "function(", "onclick=", "onerror=", "onload="
        ]
        
        let lowercasedResponse = response.lowercased()
        for pattern in suspiciousPatterns {
            if lowercasedResponse.contains(pattern) {
                logger.warning("AI response contains suspicious content", metadata: [
                    "pattern": .string(pattern),
                    "client_ip": .string(clientIP)
                ])
                throw Abort(.unprocessableEntity, reason: "AI response contains suspicious content")
            }
        }
        
        // Validate required fields for GameboxRecognition
        guard response.contains("\"guessedTitle\"") && response.contains("\"confidence\"") else {
            logger.warning("AI response missing required fields", metadata: [
                "client_ip": .string(clientIP)
            ])
            throw Abort(.unprocessableEntity, reason: "AI response missing required fields")
        }
        
        return response
    }
}
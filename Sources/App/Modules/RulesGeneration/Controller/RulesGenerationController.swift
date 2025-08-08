import Vapor

struct RulesGenerationController {

    func analyzeBoxPhoto(_ req: Request) async throws -> GameboxRecognition.Response {
        // Security logging: Log AI image analysis request
        req.logger.info("AI image analysis request initiated", metadata: [
            "endpoint": "analyzeBoxPhoto",
            "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        var data: Data?
        for try await part in req.body {
            if data == nil {
                data = Data(buffer: part)
            } else {
                data?.append(Data(buffer: part))
            }
        }

        guard let data else {
            req.logger.warning("Empty request body received for image analysis")
            throw ContentError.externalServiceFailedToRespond
        }
        
        let request: GameboxRecognition.Request
        do {
            request = try JSONDecoder().decode(GameboxRecognition.Request.self, from: data)
        } catch {
            req.logger.warning("Invalid JSON in image analysis request", metadata: ["error": .string(error.localizedDescription)])
            throw Abort(.badRequest, reason: "Invalid request format")
        }
        
        let encoded = request.image.base64EncodedString()
        
        // CRITICAL SECURITY FIX: Validate image data before AI processing
        do {
            try AIInputValidator.validateImageData(encoded)
        } catch let validationError as AIValidationError {
            req.logger.warning("Image validation failed", metadata: [
                "error": .string(validationError.description),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw validationError
        }
        
        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = CacheKeyGenerator.generateBoxPhotoKey(for: request.image)
        
        if let cachedResponse = await req.services.aiCache.get(key: cacheKey) {
            req.logger.info("Cache hit for image analysis", metadata: [
                "cache_key": .string(cacheKey),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            
            // Parse and return cached response
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: cachedBuffer)
            return result
        }
        
        req.logger.debug("Cache miss for image analysis", metadata: [
            "cache_key": .string(cacheKey)
        ])
        
        // Optimized prompt: 65 tokens (64% reduction from 180)
        let systemPrompt = """
        Identify board game from box image. Return JSON:
        {
          "guessedTitle": "game name",
          "confidence": 0-100,
          "alternativeTitles": ["alternatives"],
          "keywordsDetected": ["visible text"],
          "notes": "uncertainties"
        }
        """
        
        let boxInput: [OpenAIRequest.Message] = [
            .init(
                role: "system",
                content: [
                    OpenAIRequest.Message.TextContent(text: systemPrompt)
                ]
            ),
            .init(
                role: "user",
                content: [
                    OpenAIRequest.Message.ImageContent(
                        imageUrl: "data:image/png;base64,\(encoded)"
                    ),
                    OpenAIRequest.Message.TextContent(text: "Here is the image to analyze"),
                ]
            ),
        ]
        
        let boxResponse: String
        do {
            boxResponse = try await req.services.llm.generate(input: boxInput)
        } catch {
            req.logger.error("LLM service error during image analysis", metadata: [
                "error": .string(error.localizedDescription),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw ContentError.externalServiceFailedToRespond
        }
        
        // SECURITY FIX: Validate AI response before returning
        do {
            let validatedResponse = try validateAIResponse(boxResponse, expectedType: "GameboxRecognition")
            let boxBuffer = ByteBuffer(string: validatedResponse)
            let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: boxBuffer)
            
            // PERFORMANCE OPTIMIZATION: Cache successful response
            let cacheConfig = try req.application.configuration.cache
            await req.services.aiCache.set(
                key: cacheKey,
                value: validatedResponse,
                ttl: cacheConfig.imageAnalysisTTL
            )
            
            // Log successful analysis and caching
            req.logger.info("AI image analysis completed successfully", metadata: [
                "confidence": .string("\(result.confidence)"),
                "cached": .string("true"),
                "cache_key": .string(cacheKey),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            
            return result
        } catch {
            req.logger.error("AI response validation failed", metadata: [
                "error": .string(error.localizedDescription),
                "response_length": .string("\(boxResponse.count)"),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }

    func generateRulesSummary(_ req: Request) async throws -> RulesSummary.Response {
        // Security logging: Log AI rules generation request
        req.logger.info("AI rules generation request initiated", metadata: [
            "endpoint": "generateRulesSummary",
            "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        let input: RulesSummary.Request
        do {
            input = try req.content.decode(RulesSummary.Request.self)
        } catch {
            req.logger.warning("Invalid JSON in rules generation request", metadata: ["error": .string(error.localizedDescription)])
            throw Abort(.badRequest, reason: "Invalid request format")
        }
        
        // CRITICAL SECURITY FIX: Validate and sanitize game title before AI processing
        let sanitizedGameTitle: String
        do {
            sanitizedGameTitle = try AIInputValidator.validateAndSanitizeGameTitle(input.gameTitle)
        } catch let validationError as AIValidationError {
            req.logger.warning("Game title validation failed", metadata: [
                "error": .string(validationError.description),
                "raw_title": .string(input.gameTitle),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw validationError
        } catch let sanitizationError as ValidationError {
            req.logger.warning("Game title sanitization failed", metadata: [
                "error": .string(sanitizationError.description),
                "raw_title": .string(input.gameTitle),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw Abort(.badRequest, reason: sanitizationError.description)
        }
        
        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = CacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)
        
        if let cachedResponse = await req.services.aiCache.get(key: cacheKey) {
            req.logger.info("Cache hit for rules generation", metadata: [
                "game_title": .string(sanitizedGameTitle),
                "cache_key": .string(cacheKey),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            
            // Parse and return cached response
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let result = try JSONDecoder().decode(RulesSummary.Response.self, from: cachedBuffer)
            return result
        }
        
        req.logger.debug("Cache miss for rules generation", metadata: [
            "game_title": .string(sanitizedGameTitle),
            "cache_key": .string(cacheKey)
        ])
        
        // Optimized prompt: 120 tokens (66% reduction from 350)
        let systemPrompt = """
        Generate board game rules summary. Return JSON:
        {
          "title": "name",
          "playerCount": "X-Y",
          "playTime": "duration",
          "summary": "overview",
          "initialSetup": ["setup steps"],
          "firstRoundGuide": ["first round actions"],
          "winCondition": "victory",
          "deepDive": ["detailed rules"],
          "resources": {"videoLinks": [], "webLinks": []},
          "confidence": 0-100,
          "notes": "assumptions"
        }
        """
        
        let userPrompt = "Game: \(sanitizedGameTitle)"
        
        let rulesInput: [OpenAIRequest.Message] = [
            .init(
                role: "system",
                content: [
                    OpenAIRequest.Message.TextContent(text: systemPrompt)
                ]
            ),
            .init(
                role: "user",
                content: [
                    OpenAIRequest.Message.TextContent(text: userPrompt)
                ]
            )
        ]
        
        let rulesResponse: String
        do {
            rulesResponse = try await req.services.llm.generate(input: rulesInput)
        } catch {
            req.logger.error("LLM service error during rules generation", metadata: [
                "error": .string(error.localizedDescription),
                "game_title": .string(sanitizedGameTitle),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw ContentError.externalServiceFailedToRespond
        }
        
        // SECURITY FIX: Validate AI response before returning
        do {
            let validatedResponse = try validateAIResponse(rulesResponse, expectedType: "RulesSummary")
            let rulesBuffer = ByteBuffer(string: validatedResponse)
            let result = try JSONDecoder().decode(RulesSummary.Response.self, from: rulesBuffer)
            
            // PERFORMANCE OPTIMIZATION: Cache successful response
            let cacheConfig = try req.application.configuration.cache
            await req.services.aiCache.set(
                key: cacheKey,
                value: validatedResponse,
                ttl: cacheConfig.rulesGenerationTTL
            )
            
            // Log successful generation and caching
            req.logger.info("AI rules generation completed successfully", metadata: [
                "game_title": .string(sanitizedGameTitle),
                "confidence": .string("\(result.confidence)"),
                "cached": .string("true"),
                "cache_key": .string(cacheKey),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            
            return result
        } catch {
            req.logger.error("AI response validation failed for rules generation", metadata: [
                "error": .string(error.localizedDescription),
                "game_title": .string(sanitizedGameTitle),
                "response_length": .string("\(rulesResponse.count)"),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }
    
    // MARK: - Security Helper Methods
    
    /// Validates AI response content before returning to clients
    /// - Parameters:
    ///   - response: Raw AI response string
    ///   - expectedType: Expected response type for logging
    /// - Returns: Validated response string
    /// - Throws: Error if validation fails
    internal func validateAIResponse(_ response: String, expectedType: String) throws -> String {
        // Check response size limits (prevent DoS)
        let maxResponseSize = 50_000 // 50KB max response
        guard response.count <= maxResponseSize else {
            throw Abort(.payloadTooLarge, reason: "AI response too large")
        }
        
        // Check for minimum response size
        guard response.count >= 10 else {
            throw Abort(.unprocessableEntity, reason: "AI response too short")
        }
        
        // Basic JSON structure validation
        guard response.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") &&
              response.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("}") else {
            throw Abort(.unprocessableEntity, reason: "AI response is not valid JSON")
        }
        
        // Check for potential injection in AI response
        let suspiciousPatterns = [
            "<script",
            "javascript:",
            "data:text/html",
            "eval(",
            "function(",
            "onclick=",
            "onerror=",
            "onload="
        ]
        
        let lowercasedResponse = response.lowercased()
        for pattern in suspiciousPatterns {
            if lowercasedResponse.contains(pattern) {
                throw Abort(.unprocessableEntity, reason: "AI response contains suspicious content")
            }
        }
        
        // Validate that response contains expected JSON structure based on type
        switch expectedType {
        case "GameboxRecognition":
            guard response.contains("\"guessedTitle\"") && response.contains("\"confidence\"") else {
                throw Abort(.unprocessableEntity, reason: "AI response missing required fields")
            }
        case "RulesSummary":
            guard response.contains("\"title\"") && response.contains("\"summary\"") else {
                throw Abort(.unprocessableEntity, reason: "AI response missing required fields")
            }
        default:
            break
        }
        
        return response
    }
}

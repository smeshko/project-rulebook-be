import Vapor

struct RulesGenerationController {

    func analyzeBoxPhoto(_ req: Request) async throws -> GameboxRecognition.Response {
        // Security logging: Log AI image analysis request
        req.logger.info("AI image analysis request initiated", metadata: [
            "endpoint": "analyzeBoxPhoto",
            "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req)),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])
        
        // Collect raw binary image data from request body
        let imageData: Data
        do {
            var collectedData: Data?
            for try await part in req.body {
                if collectedData == nil {
                    collectedData = Data(buffer: part)
                } else {
                    collectedData?.append(Data(buffer: part))
                }
            }
            
            guard let data = collectedData, !data.isEmpty else {
                req.logger.warning("Empty request body received for image analysis")
                throw Abort(.badRequest, reason: "No image data provided")
            }
            imageData = data
        } catch {
            req.logger.warning("Failed to read image data from request body", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw Abort(.badRequest, reason: "Failed to read image data")
        }
        
        // Convert binary image data to base64 with data URL prefix for validation
        let base64String = imageData.base64EncodedString()
        
        // Determine MIME type from image data (default to PNG)
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
        
        // CRITICAL SECURITY FIX: Validate image data before AI processing
        do {
            try req.services.aiInputValidator.validateImageData(dataURL)
        } catch let validationError as AIValidationError {
            req.logger.warning("Image validation failed", metadata: [
                "error": .string(validationError.description),
                "client_ip": .string(req.services.ipExtractor.extractClientIP(from: req))
            ])
            throw validationError
        }
        
        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = req.services.cacheKeyGenerator.generateBoxPhotoKey(for: imageData, context: "box")
        
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
        
        // Enhanced prompt for consistent, high-quality results
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
        
        let boxResponse: String
        do {
            boxResponse = try await req.services.llm.analyzeImage(
                imageData: dataURL,
                prompt: systemPrompt,
                model: "gpt-4o-mini", 
                temperature: 0,
                maxTokens: 1000,
                useJSONMode: true
            )
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
            sanitizedGameTitle = try req.services.aiInputValidator.validateAndSanitizeGameTitle(input.gameTitle)
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
        let cacheKey = req.services.cacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)
        
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
        
        Return JSON with this exact structure:
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
            rulesResponse = try await req.services.llm.generateOptimized(
                input: combinedPrompt,
                model: "gpt-4o-mini",
                temperature: 0,
                maxTokens: 1000,
                useJSONMode: true
            )
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

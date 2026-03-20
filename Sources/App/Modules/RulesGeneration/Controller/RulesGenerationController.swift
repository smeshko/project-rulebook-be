import Foundation
import Vapor

/// Controller for AI-powered board game rules generation and image analysis.
///
/// This controller provides the core AI-powered features of the application,
/// enabling users to analyze game box images and generate comprehensive rules
/// explanations. It implements multiple layers of security, performance
/// optimization, and comprehensive logging with inline business logic.
struct RulesGenerationController {

    // MARK: - Game Box Analysis

    /// Analyzes board game box images using AI vision to identify games.
    ///
    /// - Parameter req: The HTTP request containing image data in the request body
    /// - Returns: ``GameboxRecognition.Response`` with game identification results
    func analyzeBoxPhoto(_ req: Request) async throws -> GameboxRecognition.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        let requestID = req.correlationID

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
        } catch let error as Abort {
            throw error
        } catch {
            req.logger.warning("Failed to read image data from request body", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw Abort(.badRequest, reason: "Failed to read image data")
        }

        req.logger.info("Game identification use case initiated", metadata: [
            "client_ip": .string(clientIP),
            "image_size": .string("\(imageData.count) bytes"),
            "request_id": .string(requestID),
            "timestamp": .string(ISO8601DateFormatter().string(from: Date()))
        ])

        // 1. Process and validate image data
        let dataURL = try processImageData(imageData, clientIP: clientIP, requestID: requestID, logger: req.logger)

        // 2. Validate image data for security and compliance
        do {
            try req.services.aiInputValidator.validateImageData(dataURL)
        } catch let validationError as AIProcessingError {
            req.logger.warning("Image validation failed", metadata: [
                "error": .string(validationError.description),
                "client_ip": .string(clientIP),
                "request_id": .string(requestID)
            ])
            throw validationError
        }

        // 3. Log LLM API invocation
        req.logger.info("Invoking LLM for image analysis", metadata: [
            "image_size": .string("\(imageData.count) bytes"),
            "client_ip": .string(clientIP),
            "request_id": .string(requestID)
        ])

        // 4. Generate AI analysis
        let aiResponse = try await performGameBoxAIAnalysis(
            dataURL: dataURL,
            clientIP: clientIP,
            requestID: requestID,
            logger: req.logger,
            llmService: req.services.llm
        )

        // 5. Validate response
        let gameboxRecognition = try validateGameBoxResponse(
            response: aiResponse,
            clientIP: clientIP,
            logger: req.logger,
            aiResponseValidator: req.services.aiResponseValidator
        )

        req.logger.info("Game identification completed successfully", metadata: [
            "confidence": .string("\(gameboxRecognition.confidence)"),
            "guessed_title": .string(gameboxRecognition.guessedTitle),
            "client_ip": .string(clientIP),
            "request_id": .string(requestID)
        ])

        return gameboxRecognition
    }

    // MARK: - Rules Generation

    /// Generates comprehensive game rules explanations using AI text generation.
    ///
    /// - Parameter req: The HTTP request containing ``RulesSummary.Request`` JSON
    /// - Returns: ``RulesSummary.Response`` with comprehensive rules explanation
    func generateRulesSummary(_ req: Request) async throws -> RulesSummary.Response {
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        let requestID = req.correlationID
        let timestamp = Date()

        let input: RulesSummary.Request
        do {
            input = try req.content.decode(RulesSummary.Request.self)
        } catch {
            req.logger.warning("Invalid JSON in rules generation request", metadata: ["error": .string(error.localizedDescription)])
            throw Abort(.badRequest, reason: "Invalid request format")
        }

        req.logger.info(
            "AI rules generation request initiated",
            metadata: [
                "endpoint": "generateRulesSummary",
                "client_ip": .string(clientIP),
                "request_id": .string(requestID),
                "timestamp": .string(ISO8601DateFormatter().string(from: timestamp)),
            ])

        // Basic input validation
        guard !input.gameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw Abort(.badRequest, reason: "Game title cannot be empty")
        }

        // Check for reasonable title length
        guard input.gameTitle.count <= 200 else {
            throw Abort(.badRequest, reason: "Game title too long (max 200 characters)")
        }

        // CRITICAL SECURITY FIX: Validate and sanitize game title before AI processing
        let sanitizedGameTitle: String
        do {
            sanitizedGameTitle = try req.services.aiInputValidator.validateAndSanitizeGameTitle(input.gameTitle)
        } catch let processingError as AIProcessingError {
            req.logger.warning(
                "Game title processing failed",
                metadata: [
                    "error": .string(processingError.description),
                    "raw_title": .string(input.gameTitle),
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                ])
            throw processingError
        }

        // PERFORMANCE OPTIMIZATION: Check cache first
        let cacheKey = req.services.cacheKeyGenerator.generateRulesKey(for: sanitizedGameTitle)

        if let cachedResponse = await req.services.aiCache.get(key: cacheKey) {
            req.logger.info(
                "Cache hit for rules generation",
                metadata: [
                    "game_title": .string(sanitizedGameTitle),
                    "cache_key": .string(cacheKey),
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                ])

            // Parse and return cached response
            let cachedBuffer = ByteBuffer(string: cachedResponse)
            let rulesSummary = try JSONDecoder().decode(
                RulesSummary.Response.self, from: cachedBuffer)

            return rulesSummary
        }

        req.logger.debug(
            "Cache miss for rules generation",
            metadata: [
                "game_title": .string(sanitizedGameTitle),
                "cache_key": .string(cacheKey),
                "request_id": .string(requestID),
            ])

        // Attempt to hydrate from persisted summaries before invoking the LLM
        do {
            if let storedRule = try await req.repositories.generatedRules.find(bySanitizedTitle: sanitizedGameTitle) {
                req.logger.info(
                    "Database hit for persisted rules summary",
                    metadata: [
                        "game_title": .string(sanitizedGameTitle),
                        "cache_key": .string(cacheKey),
                        "request_id": .string(requestID),
                    ])

                do {
                    let rulesSummary = makeRulesSummary(from: storedRule)

                    // Refresh Redis cache for future requests
                    let cacheConfig = try req.application.configuration.cache
                    let encodedSummary = try JSONEncoder().encode(rulesSummary)
                    if let encodedString = String(data: encodedSummary, encoding: .utf8) {
                        await req.services.aiCache.set(
                            key: cacheKey,
                            value: encodedString,
                            ttl: cacheConfig.rulesGenerationTTL
                        )
                    } else {
                        req.logger.warning(
                            "Failed to convert persisted rules summary to UTF-8 for cache hydration",
                            metadata: [
                                "game_title": .string(sanitizedGameTitle),
                                "request_id": .string(requestID),
                            ])
                    }

                    if let identifier = storedRule.id {
                        do {
                            try await req.repositories.generatedRules.touch(identifier)
                        } catch {
                            req.logger.warning(
                                "Failed to update last accessed timestamp for persisted rules summary",
                                metadata: [
                                    "error": .string(error.localizedDescription),
                                    "game_title": .string(sanitizedGameTitle),
                                    "request_id": .string(requestID),
                                ])
                        }
                    }

                    return rulesSummary
                } catch {
                    req.logger.error(
                        "Failed to map persisted rules summary, falling back to LLM generation",
                        metadata: [
                            "error": .string(error.localizedDescription),
                            "game_title": .string(sanitizedGameTitle),
                            "request_id": .string(requestID),
                        ])
                }
            }
        } catch {
            req.logger.error(
                "Database lookup for persisted rules summary failed",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedGameTitle),
                    "request_id": .string(requestID),
                ])
        }

        // Create combined input with system instructions and user prompt
        let combinedPrompt = """
            \(PromptTemplates.RulesGeneration.systemPrompt)

            \(PromptTemplates.RulesGeneration.userPrompt(gameTitle: sanitizedGameTitle))
            """

        let rulesResponse: String
        do {
            rulesResponse = try await req.services.llm.generate(input: combinedPrompt)
        } catch {
            req.logger.error(
                "LLM service error during rules generation",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedGameTitle),
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                ])
            throw ContentError.externalServiceFailedToRespond
        }

        // SECURITY FIX: Validate AI response before returning using validation service
        do {
            let validatedResponse = try req.services.aiResponseValidator.validateRulesSummaryResponse(
                rulesResponse,
                gameTitle: sanitizedGameTitle,
                clientIP: clientIP,
                logger: req.logger
            )
            let rulesBuffer = ByteBuffer(string: validatedResponse)
            let rulesSummary = try JSONDecoder().decode(
                RulesSummary.Response.self, from: rulesBuffer)

            // PERFORMANCE OPTIMIZATION: Cache successful response
            let cacheConfig = try req.application.configuration.cache
            await req.services.aiCache.set(
                key: cacheKey,
                value: validatedResponse,
                ttl: cacheConfig.rulesGenerationTTL
            )

            await persistGeneratedSummary(
                originalTitle: input.gameTitle,
                sanitizedTitle: sanitizedGameTitle,
                cacheKey: cacheKey,
                rulesSummary: rulesSummary,
                clientIP: clientIP,
                requestID: requestID,
                logger: req.logger,
                repository: req.repositories.generatedRules
            )

            // Log successful generation and caching
            req.logger.info(
                "AI rules generation completed successfully",
                metadata: [
                    "game_title": .string(sanitizedGameTitle),
                    "confidence": .string("\(rulesSummary.confidence)"),
                    "cached": .string("true"),
                    "cache_key": .string(cacheKey),
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                ])

            return rulesSummary
        } catch {
            req.logger.error(
                "AI response validation failed for rules generation",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedGameTitle),
                    "response_length": .string("\(rulesResponse.count)"),
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                ])
            throw ContentError.externalServiceFailedToRespond
        }
    }

    // MARK: - Private Helpers for Game Box Analysis

    /// Processes raw image data and validates it for AI analysis.
    private func processImageData(
        _ imageData: Data,
        clientIP: String,
        requestID: String,
        logger: Logger
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
                        logger.warning("Invalid image format - unrecognized RIFF container", metadata: [
                            "client_ip": .string(clientIP),
                            "request_id": .string(requestID),
                            "data_size": .string("\(imageData.count) bytes")
                        ])
                        throw AIProcessingError.imageFormatInvalid(reason: "Failed to convert data to base64")
                    }
                } else {
                    logger.warning("Invalid image format - truncated RIFF header", metadata: [
                        "client_ip": .string(clientIP),
                        "request_id": .string(requestID),
                        "data_size": .string("\(imageData.count) bytes")
                    ])
                    throw AIProcessingError.imageFormatInvalid(reason: "Invalid WebP format")
                }
            } else {
                logger.warning("Invalid image format - unrecognized header", metadata: [
                    "client_ip": .string(clientIP),
                    "request_id": .string(requestID),
                    "header_bytes": .string(Array(header).map { String(format: "%02X", $0) }.joined(separator: " ")),
                    "data_size": .string("\(imageData.count) bytes")
                ])
                throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
            }
        } else {
            logger.warning("Invalid image format - insufficient data", metadata: [
                "client_ip": .string(clientIP),
                "request_id": .string(requestID),
                "data_size": .string("\(imageData.count) bytes")
            ])
            throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
        }

        // Create data URL format for validation
        let dataURL = "data:\(mimeType);base64,\(base64String)"

        return dataURL
    }

    /// Performs AI image analysis using the LLM service.
    private func performGameBoxAIAnalysis(
        dataURL: String,
        clientIP: String,
        requestID: String,
        logger: Logger,
        llmService: LLMService
    ) async throws -> String {
        do {
            return try await llmService.analyzeImage(
                imageData: dataURL,
                prompt: PromptTemplates.GameBoxAnalysis.systemPrompt
            )
        } catch {
            logger.error("LLM service error during game identification", metadata: [
                "error": .string(error.localizedDescription),
                "client_ip": .string(clientIP),
                "request_id": .string(requestID)
            ])
            throw ContentError.externalServiceFailedToRespond
        }
    }

    /// Validates AI response for game box analysis.
    private func validateGameBoxResponse(
        response: String,
        clientIP: String,
        logger: Logger,
        aiResponseValidator: AIResponseValidationService
    ) throws -> GameboxRecognition.Response {
        // Validate response format and content using the dedicated validation service
        let validatedResponse = try aiResponseValidator.validateGameboxRecognitionResponse(
            response,
            clientIP: clientIP,
            logger: logger
        )

        // Parse validated response
        let responseBuffer = ByteBuffer(string: validatedResponse)
        let result = try JSONDecoder().decode(GameboxRecognition.Response.self, from: responseBuffer)

        return result
    }

    // MARK: - Private Helpers for Rules Generation

    private func makeRulesSummary(from model: GeneratedRuleModel) -> RulesSummary.Response {
        RulesSummary.Response(
            title: model.title,
            playerCount: model.playerCount,
            playTime: model.playTime,
            summary: model.summary,
            initialSetup: model.initialSetup,
            firstRoundGuide: model.firstRoundGuide,
            winCondition: model.winCondition,
            deepDive: model.deepDive,
            resources: .init(
                videoLinks: model.resourcesVideoLinks,
                webLinks: model.resourcesWebLinks
            ),
            confidence: model.confidence,
            notes: model.notes
        )
    }

    private func persistGeneratedSummary(
        originalTitle: String,
        sanitizedTitle: String,
        cacheKey: String,
        rulesSummary: RulesSummary.Response,
        clientIP: String,
        requestID: String,
        logger: Logger,
        repository: any GeneratedRuleRepository
    ) async {
        let timestamp = Date.now
        let model = GeneratedRuleModel(
            originalTitle: originalTitle,
            sanitizedTitle: sanitizedTitle,
            cacheKey: cacheKey,
            title: rulesSummary.title,
            playerCount: rulesSummary.playerCount,
            playTime: rulesSummary.playTime,
            summary: rulesSummary.summary,
            initialSetup: rulesSummary.initialSetup,
            firstRoundGuide: rulesSummary.firstRoundGuide,
            winCondition: rulesSummary.winCondition,
            deepDive: rulesSummary.deepDive,
            resourcesVideoLinks: rulesSummary.resources.videoLinks,
            resourcesWebLinks: rulesSummary.resources.webLinks,
            confidence: rulesSummary.confidence,
            notes: rulesSummary.notes,
            lastAccessedAt: timestamp
        )

        do {
            try await repository.create(model)
            logger.debug(
                "Persisted generated rules summary",
                metadata: [
                    "game_title": .string(sanitizedTitle),
                    "cache_key": .string(cacheKey),
                    "request_id": .string(requestID),
                ])
        } catch {
            logger.warning(
                "Create persisted rules summary failed, attempting update",
                metadata: [
                    "error": .string(error.localizedDescription),
                    "game_title": .string(sanitizedTitle),
                    "request_id": .string(requestID),
                ])

            do {
                if let existing = try await repository.find(bySanitizedTitle: sanitizedTitle) {
                    existing.originalTitle = originalTitle
                    existing.cacheKey = cacheKey
                    existing.title = rulesSummary.title
                    existing.playerCount = rulesSummary.playerCount
                    existing.playTime = rulesSummary.playTime
                    existing.summary = rulesSummary.summary
                    existing.initialSetup = rulesSummary.initialSetup
                    existing.firstRoundGuide = rulesSummary.firstRoundGuide
                    existing.winCondition = rulesSummary.winCondition
                    existing.deepDive = rulesSummary.deepDive
                    existing.resourcesVideoLinks = rulesSummary.resources.videoLinks
                    existing.resourcesWebLinks = rulesSummary.resources.webLinks
                    existing.confidence = rulesSummary.confidence
                    existing.notes = rulesSummary.notes
                    existing.lastAccessedAt = timestamp
                    try await repository.update(existing)
                } else {
                    logger.error(
                        "Failed to locate existing summary for upsert",
                        metadata: [
                            "game_title": .string(sanitizedTitle),
                            "request_id": .string(requestID),
                        ])
                }
            } catch {
                logger.error(
                    "Persisting generated rules summary failed",
                    metadata: [
                        "error": .string(error.localizedDescription),
                        "game_title": .string(sanitizedTitle),
                        "request_id": .string(requestID),
                    ])
            }
        }
    }
}

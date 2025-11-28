import Foundation
import Vapor

/// Use case for analyzing board game box images to identify games.
///
/// This use case contains the complete game identification business logic, including
/// image processing, AI analysis, and response validation. Following the
/// "elegant simplicity" architectural principle, the logic is implemented directly
/// in the use case rather than delegated to an over-engineered service abstraction.
///
/// ## Responsibilities
/// - **Image Processing**: Validates and processes uploaded game box images
/// - **AI Integration**: Coordinates with LLM services for vision-based analysis
/// - **Response Validation**: Ensures AI responses meet security and quality standards
/// - **Security Enforcement**: Comprehensive validation and content filtering
/// - **Error Handling**: Structured error handling with detailed logging
///
/// ## Architecture Benefits
/// - **Simplicity**: Direct implementation without unnecessary abstraction layers
/// - **Maintainability**: All related logic colocated in one place
/// - **Testability**: Pure business logic with clear dependencies
struct AnalyzeGameBoxUseCase: Query {
    
    /// Request parameters for game box analysis.
    struct Request {
        /// Raw binary image data from the uploaded game box photo
        let imageData: Data
        /// Request context with client information and logging
        let context: RequestContext
        
        init(
            imageData: Data,
            context: RequestContext
        ) {
            self.imageData = imageData
            self.context = context
        }
    }
    
    /// Response from game box analysis operation.
    struct Response {
        /// Game identification results with confidence ratings
        let gameboxRecognition: GameboxRecognition.Response
        /// Timestamp when analysis was completed
        let analyzedAt: Date

        init(
            gameboxRecognition: GameboxRecognition.Response,
            analyzedAt: Date = Date.now
        ) {
            self.gameboxRecognition = gameboxRecognition
            self.analyzedAt = analyzedAt
        }
    }
    
    // MARK: - Dependencies

    /// Service for validating AI inputs
    private let aiInputValidator: AIInputValidatorServiceInterface
    /// Service for LLM interactions
    private let llmService: LLMService
    /// Service for validating AI responses
    private let aiResponseValidator: AIResponseValidationService

    // MARK: - Initialization

    init(
        aiInputValidator: AIInputValidatorServiceInterface,
        llmService: LLMService,
        aiResponseValidator: AIResponseValidationService
    ) {
        self.aiInputValidator = aiInputValidator
        self.llmService = llmService
        self.aiResponseValidator = aiResponseValidator
    }
    
    // MARK: - Use Case Execution
    
    /// Executes the game box analysis use case.
    ///
    /// This method implements the complete game identification workflow:
    /// 1. Validates input parameters and security requirements
    /// 2. Processes and validates image data for AI analysis
    /// 3. Performs AI image analysis with optimized prompts
    /// 4. Validates successful responses
    /// 5. Returns structured response with metadata
    ///
    /// ## Error Handling
    /// - Throws AIProcessingError for invalid or malicious image data
    /// - Throws ContentError for external service failures
    /// - Provides comprehensive logging for debugging and monitoring
    ///
    /// - Parameter request: Contains image data, client context, and logging
    /// - Returns: Game identification results with analysis metadata
    /// - Throws: Service errors if validation fails or AI service unavailable
    func execute(_ request: Request) async throws -> Response {
        
        request.context.logger.info("Game identification use case initiated", metadata: [
            "client_ip": .string(request.context.clientIP),
            "image_size": .string("\(request.imageData.count) bytes"),
            "request_id": .string(request.context.requestID),
            "timestamp": .string(ISO8601DateFormatter().string(from: request.context.timestamp))
        ])
        
        // Validate input parameters
        guard !request.imageData.isEmpty else {
            request.context.logger.warning("Empty image data provided", metadata: [
                "request_id": .string(request.context.requestID)
            ])
            throw Abort(.badRequest, reason: "No image data provided")
        }
        
        // 1. Process and validate image data
        let dataURL = try processImageData(request.imageData, context: request.context)

        // 2. Log LLM API invocation
        request.context.logger.info("Invoking LLM for image analysis", metadata: [
            "image_size": .string("\(request.imageData.count) bytes"),
            "client_ip": .string(request.context.clientIP),
            "request_id": .string(request.context.requestID)
        ])

        // 3. Generate AI analysis
        let aiResponse = try await performAIAnalysis(dataURL: dataURL, context: request.context)

        // 4. Validate response
        let gameboxRecognition = try await validateResponse(
            response: aiResponse,
            context: request.context
        )
        
        request.context.logger.info("Game identification completed successfully", metadata: [
            "confidence": .string("\(gameboxRecognition.confidence)"),
            "guessed_title": .string(gameboxRecognition.guessedTitle),
            "client_ip": .string(request.context.clientIP),
            "request_id": .string(request.context.requestID)
        ])

        let response = Response(
            gameboxRecognition: gameboxRecognition,
            analyzedAt: Date.now
        )
        
        return response
    }
    
    // MARK: - Private Methods
    
    /// Processes raw image data and validates it for AI analysis.
    private func processImageData(_ imageData: Data, context: RequestContext) throws -> String {
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
                        throw AIProcessingError.imageFormatInvalid(reason: "Failed to convert data to base64")
                    }
                } else {
                    context.logger.warning("Invalid image format - truncated RIFF header", metadata: [
                        "client_ip": .string(context.clientIP),
                        "request_id": .string(context.requestID),
                        "data_size": .string("\(imageData.count) bytes")
                    ])
                    throw AIProcessingError.imageFormatInvalid(reason: "Invalid WebP format")
                }
            } else {
                context.logger.warning("Invalid image format - unrecognized header", metadata: [
                    "client_ip": .string(context.clientIP),
                    "request_id": .string(context.requestID),
                    "header_bytes": .string(Array(header).map { String(format: "%02X", $0) }.joined(separator: " ")),
                    "data_size": .string("\(imageData.count) bytes")
                ])
                throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
            }
        } else {
            context.logger.warning("Invalid image format - insufficient data", metadata: [
                "client_ip": .string(context.clientIP),
                "request_id": .string(context.requestID),
                "data_size": .string("\(imageData.count) bytes")
            ])
            throw AIProcessingError.imageFormatInvalid(reason: "Invalid image format")
        }
        
        // Create data URL format for validation
        let dataURL = "data:\(mimeType);base64,\(base64String)"
        
        // Validate image data for security and compliance
        do {
            try aiInputValidator.validateImageData(dataURL)
        } catch let validationError as AIProcessingError {
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
    private func performAIAnalysis(dataURL: String, context: RequestContext) async throws -> String {
        // Construct optimized prompt for game identification
        let systemPrompt = """
        You are an expert board game identification assistant. Analyze the game box image carefully.
        
        Follow this process:
        1. Examine all visible text on the box (title, publisher, descriptions)
        2. Note visual indicators (artwork style, component images, age ratings)
        3. Consider franchise/series if applicable
        4. Assess your confidence based on text clarity and distinctive features

        Respond ONLY in valid JSON WITHOUT any markdown formatting. Return a JSON response with this exact structure:
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
                prompt: systemPrompt
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
    
    /// Validates AI response.
    private func validateResponse(
        response: String,
        context: RequestContext
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

        return result
    }
}

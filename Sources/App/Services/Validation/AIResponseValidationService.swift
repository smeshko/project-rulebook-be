import Foundation
import Vapor

/// Domain service for validating AI-generated responses for security and quality.
///
/// This service provides centralized validation of AI responses from external services,
/// ensuring they meet security standards, structural requirements, and quality expectations
/// before being returned to clients or cached for future use.
///
/// ## Key Responsibilities
/// - **Security Validation**: Scans responses for potential injection attacks and malicious content
/// - **Structural Validation**: Ensures responses conform to expected JSON structure and format
/// - **Content Quality**: Validates that responses contain required fields and meaningful data
/// - **Size Validation**: Prevents resource exhaustion through oversized or malformed responses
/// - **Error Reporting**: Provides detailed error information for debugging and monitoring
///
/// ## Security Features
/// - **Injection Prevention**: Detects script injection, HTML injection, and function injection
/// - **Content Filtering**: Scans for suspicious patterns and data URLs
/// - **Size Limits**: Enforces maximum and minimum response sizes
/// - **Format Validation**: Validates JSON structure and required fields
/// - **Audit Logging**: Comprehensive logging for security monitoring
///
/// ## Validation Types
/// This service supports validation for different AI response types:
/// - **GameboxRecognition**: Image analysis responses with game identification data
/// - **RulesSummary**: Rules generation responses with structured game rules content
/// - **Generic**: Basic security and structural validation for any JSON response
protocol AIResponseValidationService: Sendable {
    /// Validates an AI response for GameboxRecognition (image analysis).
    ///
    /// Performs comprehensive validation specific to game box image analysis responses,
    /// ensuring required fields are present and content meets security standards.
    ///
    /// - Parameters:
    ///   - response: Raw AI response string from external service
    ///   - clientIP: Client IP address for security logging
    ///   - logger: Request logger for detailed logging
    /// - Returns: Validated response string safe for client consumption
    /// - Throws: Abort with appropriate HTTP status codes for validation failures
    func validateGameboxRecognitionResponse(
        _ response: String,
        clientIP: String,
        logger: Logger
    ) throws -> String
    
    /// Validates an AI response for RulesSummary (rules generation).
    ///
    /// Performs comprehensive validation specific to rules generation responses,
    /// ensuring required fields are present and content meets security standards.
    ///
    /// - Parameters:
    ///   - response: Raw AI response string from external service
    ///   - gameTitle: Game title being processed (for logging context)
    ///   - clientIP: Client IP address for security logging
    ///   - logger: Request logger for detailed logging
    /// - Returns: Validated response string safe for client consumption
    /// - Throws: Abort with appropriate HTTP status codes for validation failures
    func validateRulesSummaryResponse(
        _ response: String,
        gameTitle: String,
        clientIP: String,
        logger: Logger
    ) throws -> String
    
    /// Validates an AI response for generic content and security requirements.
    ///
    /// Performs basic security and structural validation that applies to any AI response,
    /// regardless of specific content type or expected structure.
    ///
    /// - Parameters:
    ///   - response: Raw AI response string from external service
    ///   - context: Context information for logging (e.g., "image_analysis", "rules_generation")
    ///   - clientIP: Client IP address for security logging
    ///   - logger: Request logger for detailed logging
    /// - Returns: Validated response string safe for client consumption
    /// - Throws: Abort with appropriate HTTP status codes for validation failures
    func validateGenericResponse(
        _ response: String,
        context: String,
        clientIP: String,
        logger: Logger
    ) throws -> String
}

/// Production implementation of AIResponseValidationService.
///
/// This implementation provides comprehensive validation capabilities with detailed
/// security scanning, structural validation, and comprehensive error reporting.
final class DefaultAIResponseValidationService: AIResponseValidationService {
    
    // MARK: - Constants
    
    private enum ValidationConstants {
        static let maxResponseSize = 100_000 // 100KB max response (structured output is larger)
        static let minResponseSize = 10 // 10 characters minimum
        
        static let suspiciousPatterns = [
            "<script", "javascript:", "data:text/html", "eval(",
            "function(", "onclick=", "onerror=", "onload="
        ]
    }
    
    // MARK: - Service Implementation
    
    func validateGameboxRecognitionResponse(
        _ response: String,
        clientIP: String,
        logger: Logger
    ) throws -> String {
        
        logger.debug("Validating GameboxRecognition response", metadata: [
            "response_size": .string("\(response.count)"),
            "client_ip": .string(clientIP)
        ])
        
        // Perform generic validation first
        let validatedResponse = try validateGenericResponse(
            response,
            context: "gamebox_recognition",
            clientIP: clientIP,
            logger: logger
        )
        
        // Validate GameboxRecognition-specific required fields
        let requiredFields = ["guessedTitle", "confidence"]
        let missingFields = requiredFields.filter { !validatedResponse.contains("\"\($0)\"") }
        
        guard missingFields.isEmpty else {
            logger.warning("GameboxRecognition response missing required fields", metadata: [
                "missing_fields": .string(missingFields.joined(separator: ", ")),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseMissingFields(
                fields: missingFields,
                responseType: "GameboxRecognition"
            )
        }
        
        // Additional validation for specific fields
        if !validatedResponse.contains("\"alternativeTitles\"") ||
           !validatedResponse.contains("\"keywordsDetected\"") ||
           !validatedResponse.contains("\"notes\"") {
            logger.info("GameboxRecognition response missing optional fields", metadata: [
                "client_ip": .string(clientIP)
            ])
        }
        
        logger.debug("GameboxRecognition response validation completed", metadata: [
            "client_ip": .string(clientIP)
        ])
        
        return validatedResponse
    }
    
    func validateRulesSummaryResponse(
        _ response: String,
        gameTitle: String,
        clientIP: String,
        logger: Logger
    ) throws -> String {
        
        logger.debug("Validating RulesSummary response", metadata: [
            "response_size": .string("\(response.count)"),
            "game_title": .string(gameTitle),
            "client_ip": .string(clientIP)
        ])
        
        // Perform generic validation first
        let validatedResponse = try validateGenericResponse(
            response,
            context: "rules_summary",
            clientIP: clientIP,
            logger: logger
        )
        
        // Validate RulesSummary-specific required fields
        let coreRequiredFields = ["title", "summary"]
        let missingCoreFields = coreRequiredFields.filter { !validatedResponse.contains("\"\($0)\"") }
        
        guard missingCoreFields.isEmpty else {
            logger.warning("RulesSummary response missing required fields", metadata: [
                "missing_fields": .string(missingCoreFields.joined(separator: ", ")),
                "game_title": .string(gameTitle),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseMissingFields(
                fields: missingCoreFields,
                responseType: "RulesSummary"
            )
        }
        
        // Additional validation for specific fields
        let requiredFields = [
            "\"playerCount\"", "\"playTime\"", "\"complexity\"",
            "\"recommendedAge\"", "\"mechanics\"", "\"initialSetup\"",
            "\"firstRoundGuide\"", "\"winCondition\"", "\"endGameTrigger\"",
            "\"turnStructure\"", "\"components\"", "\"scoringCategories\"",
            "\"glossary\"", "\"commonMistakes\"", "\"quickReference\"",
            "\"deepDive\"", "\"resources\"", "\"confidence\"", "\"notes\""
        ]
        
        let missingFields = requiredFields.filter { !validatedResponse.contains($0) }
        if !missingFields.isEmpty {
            logger.info("RulesSummary response missing some fields", metadata: [
                "missing_fields": .string(missingFields.joined(separator: ", ")),
                "game_title": .string(gameTitle),
                "client_ip": .string(clientIP)
            ])
        }
        
        logger.debug("RulesSummary response validation completed", metadata: [
            "game_title": .string(gameTitle),
            "client_ip": .string(clientIP)
        ])
        
        return validatedResponse
    }
    
    func validateGenericResponse(
        _ response: String,
        context: String,
        clientIP: String,
        logger: Logger
    ) throws -> String {
        
        logger.debug("Performing generic response validation", metadata: [
            "context": .string(context),
            "response_size": .string("\(response.count)"),
            "client_ip": .string(clientIP)
        ])
        
        // Size validation
        try validateResponseSize(response, context: context, clientIP: clientIP, logger: logger)
        
        // Structure validation
        try validateJSONStructure(response, context: context, clientIP: clientIP, logger: logger)
        
        // Security validation
        try validateSecurityThreats(response, context: context, clientIP: clientIP, logger: logger)
        
        logger.debug("Generic response validation completed", metadata: [
            "context": .string(context),
            "client_ip": .string(clientIP)
        ])
        
        return response
    }
    
    // MARK: - Private Validation Methods
    
    /// Validates response size to prevent resource exhaustion.
    private func validateResponseSize(
        _ response: String,
        context: String,
        clientIP: String,
        logger: Logger
    ) throws {
        
        // Check maximum size (DoS protection)
        guard response.count <= ValidationConstants.maxResponseSize else {
            logger.warning("AI response too large", metadata: [
                "size": .string("\(response.count)"),
                "max_allowed": .string("\(ValidationConstants.maxResponseSize)"),
                "context": .string(context),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseTooLarge(
                maxSize: ValidationConstants.maxResponseSize,
                context: context
            )
        }
        
        // Check minimum size (quality assurance)
        guard response.count >= ValidationConstants.minResponseSize else {
            logger.warning("AI response too short", metadata: [
                "size": .string("\(response.count)"),
                "min_required": .string("\(ValidationConstants.minResponseSize)"),
                "context": .string(context),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseTooShort(
                minSize: ValidationConstants.minResponseSize,
                context: context
            )
        }
    }
    
    /// Validates JSON structure and format.
    private func validateJSONStructure(
        _ response: String,
        context: String,
        clientIP: String,
        logger: Logger
    ) throws {
        
        let trimmedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedResponse.hasPrefix("{") && trimmedResponse.hasSuffix("}") else {
            logger.warning("AI response invalid JSON structure", metadata: [
                "context": .string(context),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseStructureInvalid(context: context)
        }
        
        // Attempt basic JSON parsing to validate structure
        do {
            _ = try JSONSerialization.jsonObject(with: Data(response.utf8), options: [])
        } catch {
            logger.warning("AI response JSON parsing failed", metadata: [
                "error": .string(error.localizedDescription),
                "context": .string(context),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.responseInvalid(
                reason: "Invalid JSON structure: \(error.localizedDescription)",
                responseType: context
            )
        }
    }
    
    /// Validates response content for security threats.
    private func validateSecurityThreats(
        _ response: String,
        context: String,
        clientIP: String,
        logger: Logger
    ) throws {
        
        let lowercasedResponse = response.lowercased()
        
        for pattern in ValidationConstants.suspiciousPatterns {
            if lowercasedResponse.contains(pattern) {
                logger.warning("AI response contains suspicious content", metadata: [
                    "pattern": .string(pattern),
                    "context": .string(context),
                    "client_ip": .string(clientIP)
                ])
                throw AIProcessingError.suspiciousContent(
                    pattern: pattern,
                    context: context
                )
            }
        }
        
        // Additional security checks for data URLs and encoded content
        if lowercasedResponse.contains("data:") && 
           (lowercasedResponse.contains("base64") || lowercasedResponse.contains("javascript")) {
            logger.warning("AI response contains suspicious data URL", metadata: [
                "context": .string(context),
                "client_ip": .string(clientIP)
            ])
            throw AIProcessingError.suspiciousBinaryContent(context: context)
        }
    }
}
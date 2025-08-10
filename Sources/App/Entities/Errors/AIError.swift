import Vapor
import Foundation

// MARK: - AI Validation Error

/// Errors related to AI input validation and security screening.
///
/// This enum represents various validation failures that can occur when processing
/// user inputs for AI services. Each error type corresponds to specific security
/// or data quality issues that prevent safe processing.
///
/// ## Error Categories
///
/// ### Image Validation Errors
/// - **Data Issues**: Empty data, oversized files, format problems
/// - **Security Issues**: Suspicious content, invalid formats
/// - **Performance Issues**: Size limits to prevent resource exhaustion
///
/// ### Text Validation Errors  
/// - **Format Issues**: Invalid game title formats, character composition problems
/// - **Security Issues**: Prompt injection attempts, suspicious patterns
/// - **Content Issues**: Repetitive patterns, encoded content attacks
///
/// ## HTTP Response Mapping
///
/// Errors are automatically converted to appropriate HTTP status codes:
/// - `400 Bad Request`: Invalid format, empty data, general validation failures
/// - `413 Payload Too Large`: Oversized images or text inputs
/// - `403 Forbidden`: Security violations, prompt injection attempts
///
/// ## Usage in Security Pipeline
///
/// These errors are thrown by:
/// - ``AIInputValidatorService`` during input validation
/// - ``PromptSanitizerService`` during content sanitization
/// - Image processing and validation routines
/// - Security scanning and pattern detection systems
enum AIValidationError: Error, CustomStringConvertible {
    /// Image data is empty or not provided.
    ///
    /// Thrown when required image data is missing from the request.
    /// HTTP Status: 400 Bad Request
    case emptyImageData
    
    /// Image exceeds the maximum allowed size limit.
    ///
    /// Thrown when uploaded images exceed the 10MB size limit to prevent
    /// resource exhaustion and potential DoS attacks.
    /// HTTP Status: 413 Payload Too Large
    case imageTooLarge(maxSizeMB: Int)
    
    /// Image format is invalid or unsupported.
    ///
    /// Thrown when image data is not valid base64 or doesn't have a proper
    /// data URL prefix with supported MIME type.
    /// HTTP Status: 400 Bad Request
    case invalidImageFormat
    
    /// Image data contains suspicious or potentially malicious content.
    ///
    /// Thrown when image data validation detects patterns that could
    /// indicate security threats or malicious content.
    /// HTTP Status: 400 Bad Request
    case suspiciousImageContent
    
    /// Game title format is invalid.
    ///
    /// Thrown when game title doesn't meet format requirements such as
    /// insufficient alphanumeric characters or excessive special characters.
    /// HTTP Status: 400 Bad Request
    case invalidGameTitleFormat(String)
    
    /// Prompt injection attack detected in user input.
    ///
    /// Thrown when advanced pattern analysis identifies potential prompt
    /// injection attempts designed to manipulate AI behavior.
    /// HTTP Status: 403 Forbidden
    case promptInjectionDetected(pattern: String, category: String, context: String)
    
    /// Excessive character repetition detected.
    ///
    /// Thrown when input contains repeated characters that could indicate
    /// DoS attempts or buffer overflow exploitation attempts.
    /// HTTP Status: 403 Forbidden
    case excessiveRepetition(context: String)
    
    /// Suspicious binary or encoded content detected.
    ///
    /// Thrown when input contains patterns suggesting encoded malicious
    /// content such as base64 or hex-encoded payloads.
    /// HTTP Status: 403 Forbidden
    case suspiciousBinaryContent(context: String)
    
    var description: String {
        switch self {
        case .emptyImageData:
            return "Image data cannot be empty"
        case .imageTooLarge(let maxSizeMB):
            return "Image size exceeds \(maxSizeMB)MB limit"
        case .invalidImageFormat:
            return "Invalid image format - must be valid base64 encoded image"
        case .suspiciousImageContent:
            return "Image data contains suspicious content"
        case .invalidGameTitleFormat(let reason):
            return "Invalid game title format: \(reason)"
        case .promptInjectionDetected(let pattern, let category, let context):
            return "Potential prompt injection detected in \(context): '\(pattern)' (\(category))"
        case .excessiveRepetition(let context):
            return "Excessive character repetition detected in \(context)"
        case .suspiciousBinaryContent(let context):
            return "Suspicious encoded content detected in \(context)"
        }
    }
}

// MARK: - Validation Error

/// Errors related to general input validation and sanitization.
///
/// This enum represents validation failures from the sanitization layer,
/// focusing on content cleaning and basic format validation before
/// more advanced security screening.
///
/// ## Validation Categories
///
/// ### Length Validation
/// - **Empty Inputs**: Required fields that are empty or whitespace-only
/// - **Size Limits**: Inputs that exceed reasonable length constraints
/// - **Minimum Requirements**: Inputs too short to be meaningful
///
/// ### Content Validation
/// - **Sanitization Results**: Content that becomes invalid after cleaning
/// - **Suspicious Patterns**: Basic pattern detection for known attack vectors
/// - **Format Requirements**: Content that doesn't meet basic format expectations
///
/// ## Processing Pipeline
///
/// These errors are typically thrown by:
/// - ``PromptSanitizerService`` during initial content cleaning
/// - Basic validation routines before advanced security screening
/// - Length and format validation before AI processing
///
/// ## HTTP Response Mapping
///
/// - `400 Bad Request`: Empty inputs, format issues, insufficient content
/// - `413 Payload Too Large`: Inputs exceeding length limits
/// - `403 Forbidden`: Suspicious content patterns detected
enum ValidationError: Error, CustomStringConvertible {
    /// Game title is empty or contains only whitespace.
    ///
    /// Thrown when required game title field is not provided or contains
    /// only whitespace characters after trimming.
    /// HTTP Status: 400 Bad Request
    case emptyGameTitle
    
    /// Generic input is empty or contains only whitespace.
    ///
    /// Thrown when required input fields are empty after trimming whitespace.
    /// HTTP Status: 400 Bad Request
    case emptyInput
    
    /// Game title exceeds maximum allowed length.
    ///
    /// Thrown when game title is longer than the 100-character limit
    /// designed to prevent resource exhaustion.
    /// HTTP Status: 413 Payload Too Large
    case gameTitleTooLong(maxLength: Int)
    
    /// Game title is too short after sanitization.
    ///
    /// Thrown when game title has fewer than 2 characters remaining
    /// after dangerous character removal.
    /// HTTP Status: 400 Bad Request
    case gameTitleTooShort
    
    /// Input exceeds maximum allowed length.
    ///
    /// Thrown when generic input fields exceed their configured length limits.
    /// HTTP Status: 413 Payload Too Large
    case inputTooLong(maxLength: Int)
    
    /// Suspicious content pattern detected during basic validation.
    ///
    /// Thrown when initial pattern scanning identifies known attack patterns
    /// before more sophisticated validation occurs.
    /// HTTP Status: 403 Forbidden
    case suspiciousContent(pattern: String)
    
    /// No valid content remains after sanitization process.
    ///
    /// Thrown when character filtering removes all meaningful content,
    /// leaving only whitespace or empty strings.
    /// HTTP Status: 400 Bad Request
    case noValidContentAfterSanitization
    
    var description: String {
        switch self {
        case .emptyGameTitle:
            return "Game title cannot be empty"
        case .emptyInput:
            return "Input cannot be empty"
        case .gameTitleTooLong(let maxLength):
            return "Game title exceeds maximum length of \(maxLength) characters"
        case .gameTitleTooShort:
            return "Game title is too short after sanitization"
        case .inputTooLong(let maxLength):
            return "Input exceeds maximum length of \(maxLength) characters"
        case .suspiciousContent(let pattern):
            return "Suspicious content detected: \(pattern)"
        case .noValidContentAfterSanitization:
            return "No valid content remaining after sanitization"
        }
    }
}

// MARK: - HTTP Error Extension

extension AIValidationError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .emptyImageData:
            return .badRequest
        case .imageTooLarge:
            return .payloadTooLarge
        case .invalidImageFormat, .suspiciousImageContent, .invalidGameTitleFormat:
            return .badRequest
        case .promptInjectionDetected, .excessiveRepetition, .suspiciousBinaryContent:
            return .forbidden
        }
    }
    
    var reason: String {
        return description
    }
}

extension ValidationError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .emptyGameTitle, .emptyInput, .gameTitleTooShort, .noValidContentAfterSanitization:
            return .badRequest
        case .gameTitleTooLong, .inputTooLong:
            return .payloadTooLarge
        case .suspiciousContent:
            return .forbidden
        }
    }
    
    var reason: String {
        return description
    }
}
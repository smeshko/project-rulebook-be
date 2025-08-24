import Vapor
import Foundation

// MARK: - AI Processing Error

/// Unified error type for all AI processing validation and security screening.
///
/// This enum represents all validation failures that can occur during the AI processing
/// pipeline, from initial input validation through response validation. Each error type
/// corresponds to specific security or data quality issues that prevent safe processing.
///
/// ## Error Categories
///
/// ### Input Validation Errors
/// - **Empty Data**: Required fields that are empty or whitespace-only
/// - **Size Limits**: Inputs that exceed reasonable length constraints or are too small
/// - **Format Issues**: Invalid formats, character composition problems
///
/// ### Security Errors
/// - **Injection Attacks**: Prompt injection attempts, suspicious patterns
/// - **Malicious Content**: Encoded content attacks, suspicious binary data
/// - **DoS Prevention**: Excessive repetition, oversized inputs
///
/// ### AI Response Validation Errors
/// - **Structure Issues**: Invalid JSON, missing required fields
/// - **Content Quality**: Insufficient or invalid response content
/// - **Security Scanning**: Suspicious content in AI responses
///
/// ### Image Processing Errors
/// - **Data Issues**: Empty data, invalid formats, unsupported types
/// - **Security Issues**: Suspicious image content, malicious data
/// - **Performance Issues**: Size limits to prevent resource exhaustion
///
/// ## HTTP Response Mapping
///
/// Errors are automatically converted to appropriate HTTP status codes:
/// - `400 Bad Request`: Invalid format, empty data, general validation failures
/// - `413 Payload Too Large`: Oversized inputs or responses
/// - `403 Forbidden`: Security violations, injection attempts, suspicious content
/// - `422 Unprocessable Entity`: AI response validation failures
///
/// ## Usage in Security Pipeline
///
/// These errors are thrown by:
/// - ``AIInputValidatorService`` during input validation
/// - ``PromptSanitizerService`` during content sanitization
/// - ``AIResponseValidationService`` during response validation
/// - Image processing and validation routines
/// - Security scanning and pattern detection systems
enum AIProcessingError: Error, CustomStringConvertible {
    
    // MARK: - Input Validation Errors
    
    /// Input is empty or contains only whitespace.
    ///
    /// Thrown when required input fields are empty after trimming whitespace.
    /// HTTP Status: 400 Bad Request
    case emptyInput(context: String)
    
    /// Input exceeds maximum allowed length.
    ///
    /// Thrown when inputs exceed their configured length limits to prevent
    /// resource exhaustion and potential DoS attacks.
    /// HTTP Status: 413 Payload Too Large
    case inputTooLarge(maxSize: Int, context: String)
    
    /// Input is too short after processing.
    ///
    /// Thrown when input has insufficient content remaining after sanitization
    /// or doesn't meet minimum length requirements.
    /// HTTP Status: 400 Bad Request
    case inputTooShort(minSize: Int, context: String)
    
    /// Input format is invalid.
    ///
    /// Thrown when input doesn't meet format requirements such as insufficient
    /// alphanumeric characters, invalid structure, or unsupported encoding.
    /// HTTP Status: 400 Bad Request
    case invalidFormat(reason: String, context: String)
    
    // MARK: - Security Errors
    
    /// Prompt injection attack detected in user input.
    ///
    /// Thrown when advanced pattern analysis identifies potential prompt
    /// injection attempts designed to manipulate AI behavior.
    /// HTTP Status: 403 Forbidden
    case promptInjectionDetected(pattern: String, category: String, context: String)
    
    /// Suspicious content pattern detected.
    ///
    /// Thrown when pattern scanning identifies known attack patterns or
    /// potentially malicious content during validation.
    /// HTTP Status: 403 Forbidden
    case suspiciousContent(pattern: String, context: String)
    
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
    
    // MARK: - AI Response Validation Errors
    
    /// AI response is invalid or malformed.
    ///
    /// Thrown when AI response doesn't meet basic validity requirements
    /// such as proper JSON structure or expected format.
    /// HTTP Status: 422 Unprocessable Entity
    case responseInvalid(reason: String, responseType: String)
    
    /// AI response is missing required fields.
    ///
    /// Thrown when AI response doesn't contain required fields for the
    /// specific response type being validated.
    /// HTTP Status: 422 Unprocessable Entity
    case responseMissingFields(fields: [String], responseType: String)
    
    /// AI response structure is invalid.
    ///
    /// Thrown when AI response has structural issues such as invalid JSON
    /// or doesn't conform to expected schema.
    /// HTTP Status: 422 Unprocessable Entity
    case responseStructureInvalid(context: String)
    
    /// AI response exceeds size limits.
    ///
    /// Thrown when AI response is too large and could cause resource
    /// exhaustion or performance issues.
    /// HTTP Status: 413 Payload Too Large
    case responseTooLarge(maxSize: Int, context: String)
    
    /// AI response is too short or empty.
    ///
    /// Thrown when AI response doesn't contain sufficient content to
    /// be meaningful or useful.
    /// HTTP Status: 422 Unprocessable Entity
    case responseTooShort(minSize: Int, context: String)
    
    // MARK: - Image Processing Errors
    
    /// Image data is empty or not provided.
    ///
    /// Thrown when required image data is missing from the request.
    /// HTTP Status: 400 Bad Request
    case imageDataEmpty
    
    /// Image data format is invalid.
    ///
    /// Thrown when image data is not valid base64 or doesn't have proper
    /// data URL prefix with supported MIME type.
    /// HTTP Status: 400 Bad Request
    case imageFormatInvalid(reason: String)
    
    /// Image data contains suspicious content.
    ///
    /// Thrown when image data validation detects patterns that could
    /// indicate security threats or malicious content.
    /// HTTP Status: 400 Bad Request
    case imageContentSuspicious
    
    // MARK: - Content Processing Errors
    
    /// No valid content remains after sanitization.
    ///
    /// Thrown when character filtering removes all meaningful content,
    /// leaving only whitespace or empty strings.
    /// HTTP Status: 400 Bad Request
    case noValidContentAfterSanitization
    
    var description: String {
        switch self {
        // Input Validation Errors
        case .emptyInput(let context):
            return "Input cannot be empty in \(context)"
        case .inputTooLarge(let maxSize, let context):
            return "Input exceeds maximum size of \(maxSize) in \(context)"
        case .inputTooShort(let minSize, let context):
            return "Input is too short (minimum \(minSize) required) in \(context)"
        case .invalidFormat(let reason, let context):
            return "Invalid format in \(context): \(reason)"
            
        // Security Errors
        case .promptInjectionDetected(let pattern, let category, let context):
            return "Potential prompt injection detected in \(context): '\(pattern)' (\(category))"
        case .suspiciousContent(let pattern, let context):
            return "Suspicious content detected in \(context): \(pattern)"
        case .excessiveRepetition(let context):
            return "Excessive character repetition detected in \(context)"
        case .suspiciousBinaryContent(let context):
            return "Suspicious encoded content detected in \(context)"
            
        // AI Response Validation Errors
        case .responseInvalid(let reason, let responseType):
            return "AI response invalid for \(responseType): \(reason)"
        case .responseMissingFields(let fields, let responseType):
            return "AI response missing required fields for \(responseType): \(fields.joined(separator: ", "))"
        case .responseStructureInvalid(let context):
            return "AI response structure invalid in \(context)"
        case .responseTooLarge(let maxSize, let context):
            return "AI response too large (max \(maxSize)) in \(context)"
        case .responseTooShort(let minSize, let context):
            return "AI response too short (min \(minSize)) in \(context)"
            
        // Image Processing Errors
        case .imageDataEmpty:
            return "Image data cannot be empty"
        case .imageFormatInvalid(let reason):
            return "Invalid image format: \(reason)"
        case .imageContentSuspicious:
            return "Image data contains suspicious content"
            
        // Content Processing Errors
        case .noValidContentAfterSanitization:
            return "No valid content remaining after sanitization"
        }
    }
}

// MARK: - HTTP Error Extension

extension AIProcessingError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        // Input Validation Errors
        case .emptyInput, .inputTooShort, .invalidFormat, .noValidContentAfterSanitization:
            return .badRequest
        case .inputTooLarge:
            return .payloadTooLarge
            
        // Security Errors
        case .promptInjectionDetected, .suspiciousContent, .excessiveRepetition, .suspiciousBinaryContent:
            return .forbidden
            
        // AI Response Validation Errors
        case .responseInvalid, .responseMissingFields, .responseStructureInvalid, .responseTooShort:
            return .unprocessableEntity
        case .responseTooLarge:
            return .payloadTooLarge
            
        // Image Processing Errors
        case .imageDataEmpty, .imageFormatInvalid, .imageContentSuspicious:
            return .badRequest
        }
    }
    
    var reason: String {
        return description
    }
}
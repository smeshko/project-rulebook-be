import Vapor
import Foundation

// MARK: - AI Validation Error

enum AIValidationError: Error, CustomStringConvertible {
    case emptyImageData
    case imageTooLarge(maxSizeMB: Int)
    case invalidImageFormat
    case suspiciousImageContent
    case invalidGameTitleFormat(String)
    case promptInjectionDetected(pattern: String, category: String, context: String)
    case excessiveRepetition(context: String)
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

enum ValidationError: Error, CustomStringConvertible {
    case emptyGameTitle
    case emptyInput
    case gameTitleTooLong(maxLength: Int)
    case gameTitleTooShort
    case inputTooLong(maxLength: Int)
    case suspiciousContent(pattern: String)
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
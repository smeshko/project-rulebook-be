import Vapor
import Foundation

/// Validator for AI-related user inputs to prevent prompt injection and ensure data integrity
struct AIInputValidator {
    
    // MARK: - Game Title Validation
    
    /// Validates a game title input for AI processing
    /// - Parameter gameTitle: The game title to validate
    /// - Throws: `AIValidationError` if validation fails
    static func validateGameTitle(_ gameTitle: String) throws {
        // Basic sanitization and validation
        let sanitizedTitle = try PromptSanitizer.sanitizeGameTitle(gameTitle)
        
        // Additional AI-specific validation
        try validateAgainstPromptInjection(sanitizedTitle, context: "game title")
        try validateGameTitleFormat(sanitizedTitle)
    }
    
    /// Validates and sanitizes a game title, returning the safe version
    /// - Parameter gameTitle: The raw game title input
    /// - Returns: Sanitized and validated game title
    /// - Throws: `AIValidationError` if validation fails
    static func validateAndSanitizeGameTitle(_ gameTitle: String) throws -> String {
        let sanitized = try PromptSanitizer.sanitizeGameTitle(gameTitle)
        try validateGameTitle(sanitized)
        return sanitized
    }
    
    // MARK: - Image Analysis Validation
    
    /// Validates image data for AI analysis
    /// - Parameter imageData: Base64 encoded image data
    /// - Throws: `AIValidationError` if validation fails
    static func validateImageData(_ imageData: String) throws {
        // Check if base64 data is valid
        guard !imageData.isEmpty else {
            throw AIValidationError.emptyImageData
        }
        
        // Check reasonable size limits (base64 encoded, so ~4/3 of actual size)
        // Max 10MB actual image = ~13.3MB base64
        let maxBase64Size = 14_000_000 // ~10MB image
        guard imageData.count <= maxBase64Size else {
            throw AIValidationError.imageTooLarge(maxSizeMB: 10)
        }
        
        // Basic base64 validation
        guard isValidBase64(imageData) else {
            throw AIValidationError.invalidImageFormat
        }
        
        // Check for suspicious patterns in base64 data that might indicate injection attempts
        let suspiciousPatterns = [
            "system:",
            "prompt:",
            "ignore",
            "instruction:",
            "override"
        ]
        
        let lowercased = imageData.lowercased()
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) {
                throw AIValidationError.suspiciousImageContent
            }
        }
    }
    
    // MARK: - General AI Input Validation
    
    /// Validates any text input destined for AI processing
    /// - Parameters:
    ///   - input: The text input to validate
    ///   - context: Context description for error messages
    ///   - maxLength: Maximum allowed length
    /// - Throws: `AIValidationError` if validation fails
    static func validateAITextInput(_ input: String, context: String, maxLength: Int = 500) throws {
        let sanitized = try PromptSanitizer.sanitizeTextInput(input, maxLength: maxLength)
        try validateAgainstPromptInjection(sanitized, context: context)
    }
    
    // MARK: - Private Validation Methods
    
    /// Validates game title format and content
    private static func validateGameTitleFormat(_ title: String) throws {
        // Game titles should contain at least one letter
        guard title.contains(where: { $0.isLetter }) else {
            throw AIValidationError.invalidGameTitleFormat("Game title must contain letters")
        }
        
        // Game titles shouldn't be all numbers
        guard !title.allSatisfy({ $0.isNumber || $0.isWhitespace }) else {
            throw AIValidationError.invalidGameTitleFormat("Game title cannot be only numbers")
        }
        
        // Check for reasonable character variety (not all the same character)
        let uniqueChars = Set(title.lowercased().filter { !$0.isWhitespace })
        guard uniqueChars.count >= 2 else {
            throw AIValidationError.invalidGameTitleFormat("Game title must contain varied characters")
        }
    }
    
    /// Advanced prompt injection detection
    private static func validateAgainstPromptInjection(_ input: String, context: String) throws {
        let lowercased = input.lowercased()
        
        // Advanced injection patterns
        let advancedPatterns = [
            // Command injection patterns
            ("act as", "command injection"),
            ("pretend you are", "role manipulation"),
            ("ignore previous", "instruction override"),
            ("disregard the above", "instruction override"),
            ("new instructions", "instruction override"),
            ("system message", "system manipulation"),
            ("assistant response", "response manipulation"),
            ("user input", "input manipulation"),
            
            // Code execution patterns
            ("execute", "code execution"),
            ("eval(", "code execution"),
            ("script", "script injection"),
            ("function(", "function injection"),
            ("javascript:", "script injection"),
            ("data:text/html", "HTML injection"),
            
            // Data extraction patterns
            ("show me", "data extraction"),
            ("reveal", "data extraction"),
            ("display all", "data extraction"),
            ("list all", "data extraction"),
            ("dump", "data extraction"),
            
            // Context breaking patterns
            ("end of game", "context breaking"),
            ("stop analyzing", "context breaking"),
            ("exit game mode", "context breaking"),
            ("switch to", "mode switching"),
            ("change task", "task switching")
        ]
        
        for (pattern, category) in advancedPatterns {
            if lowercased.contains(pattern) {
                throw AIValidationError.promptInjectionDetected(
                    pattern: pattern,
                    category: category,
                    context: context
                )
            }
        }
        
        // Check for excessive repetition (potential spam/DoS)
        if hasExcessiveRepetition(input) {
            throw AIValidationError.excessiveRepetition(context: context)
        }
        
        // Check for binary/encoded data patterns that might hide injection
        if containsSuspiciousBinaryPatterns(input) {
            throw AIValidationError.suspiciousBinaryContent(context: context)
        }
    }
    
    /// Checks for excessive character repetition
    private static func hasExcessiveRepetition(_ input: String) -> Bool {
        let maxRepeats = 5
        var currentChar: Character?
        var currentCount = 0
        
        for char in input.lowercased() {
            if char == currentChar {
                currentCount += 1
                if currentCount >= maxRepeats {
                    return true
                }
            } else {
                currentChar = char
                currentCount = 1
            }
        }
        
        return false
    }
    
    /// Checks for suspicious binary or encoded patterns
    private static func containsSuspiciousBinaryPatterns(_ input: String) -> Bool {
        // Check for high concentration of non-printable ASCII representations
        let suspiciousPatterns = [
            "\\x", "\\u", "\\n", "\\r", "\\t",  // Escape sequences
            "%20", "%22", "%3C", "%3E",        // URL encoding
            "&lt;", "&gt;", "&quot;",          // HTML encoding
            "base64:",                         // Base64 indicators
        ]
        
        let lowercased = input.lowercased()
        var suspiciousCount = 0
        
        for pattern in suspiciousPatterns {
            let components = lowercased.components(separatedBy: pattern)
            suspiciousCount += components.count - 1 // Count occurrences
        }
        
        // If more than 2 suspicious patterns, flag it
        return suspiciousCount > 2
    }
    
    /// Basic base64 validation
    private static func isValidBase64(_ string: String) -> Bool {
        // Remove data URL prefix if present
        let cleanString = string.hasPrefix("data:") 
            ? String(string.drop(while: { $0 != "," }).dropFirst())
            : string
        
        // Base64 validation
        let base64Regex = "^[A-Za-z0-9+/]*={0,2}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", base64Regex)
        return predicate.evaluate(with: cleanString)
    }
}

// MARK: - AI Validation Errors

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

// MARK: - Vapor Error Conformance

extension AIValidationError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .emptyImageData, .invalidImageFormat, .invalidGameTitleFormat:
            return .badRequest
        case .imageTooLarge:
            return .payloadTooLarge
        case .suspiciousImageContent, .promptInjectionDetected, .excessiveRepetition, .suspiciousBinaryContent:
            return .unprocessableEntity
        }
    }
    
    var reason: String {
        return self.description
    }
}
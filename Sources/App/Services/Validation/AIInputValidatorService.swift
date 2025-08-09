import Vapor
import Foundation

// MARK: - Service Protocol

/// Protocol for validating AI-related user inputs
protocol AIInputValidatorServiceInterface: Sendable {
    /// Returns a service instance for the given request
    func `for`(_ request: Request) -> AIInputValidatorServiceInterface
    
    /// Validates a game title input for AI processing
    func validateGameTitle(_ gameTitle: String) throws
    
    /// Validates and sanitizes a game title, returning the safe version
    func validateAndSanitizeGameTitle(_ gameTitle: String) throws -> String
    
    /// Validates image data for AI analysis
    func validateImageData(_ imageData: String) throws
}

// MARK: - Default Implementation

/// Default implementation of AI input validation service
struct DefaultAIInputValidatorService: AIInputValidatorServiceInterface {
    
    private let app: Application?
    private let logger: Logger?
    private let promptSanitizer: PromptSanitizerServiceInterface?
    
    // MARK: - Initialization
    
    init(app: Application? = nil, promptSanitizer: PromptSanitizerServiceInterface? = nil) {
        self.app = app
        self.logger = app?.logger
        self.promptSanitizer = promptSanitizer ?? app?.services.promptSanitizer.service
    }
    
    // MARK: - Service Pattern
    
    func `for`(_ request: Request) -> AIInputValidatorServiceInterface {
        return DefaultAIInputValidatorService(
            app: request.application,
            promptSanitizer: request.services.promptSanitizer
        )
    }
    
    // MARK: - Game Title Validation
    
    /// Validates a game title input for AI processing
    func validateGameTitle(_ gameTitle: String) throws {
        // Basic sanitization and validation
        guard let promptSanitizer = promptSanitizer else {
            throw Abort(.internalServerError, reason: "Prompt sanitizer service not available")
        }
        
        let sanitizedTitle = try promptSanitizer.sanitizeGameTitle(gameTitle)
        
        // Additional AI-specific validation
        try validateAgainstPromptInjection(sanitizedTitle, context: "game title")
        try validateGameTitleFormat(sanitizedTitle)
    }
    
    /// Validates and sanitizes a game title, returning the safe version
    func validateAndSanitizeGameTitle(_ gameTitle: String) throws -> String {
        guard let promptSanitizer = promptSanitizer else {
            throw Abort(.internalServerError, reason: "Prompt sanitizer service not available")
        }
        
        let sanitized = try promptSanitizer.sanitizeGameTitle(gameTitle)
        try validateGameTitle(sanitized)
        return sanitized
    }
    
    // MARK: - Image Analysis Validation
    
    /// Validates image data for AI analysis
    func validateImageData(_ imageData: String) throws {
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
        
        // Check for suspicious patterns that might indicate non-image content
        try validateAgainstSuspiciousImageData(imageData)
        
        logger?.debug("Image data validation passed", metadata: [
            "size": .string("\(imageData.count) bytes")
        ])
    }
    
    // MARK: - Private Validation Methods
    
    /// Validates game title format beyond basic sanitization
    private func validateGameTitleFormat(_ title: String) throws {
        // Must contain at least one alphanumeric character
        let alphanumericPattern = ".*[a-zA-Z0-9].*"
        guard title.range(of: alphanumericPattern, options: .regularExpression) != nil else {
            throw AIValidationError.invalidGameTitleFormat("Must contain at least one letter or number")
        }
        
        // Check for excessive special characters (more than 30% of the string)
        let specialCharCount = title.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        let specialCharRatio = Double(specialCharCount) / Double(title.count)
        if specialCharRatio > 0.3 {
            throw AIValidationError.invalidGameTitleFormat("Too many special characters")
        }
    }
    
    /// Advanced prompt injection detection using patterns and heuristics
    private func validateAgainstPromptInjection(_ input: String, context: String) throws {
        let lowercased = input.lowercased()
        
        // Advanced injection patterns that might bypass basic sanitization
        let advancedPatterns: [(pattern: String, category: String)] = [
            // Role manipulation attempts
            ("you are", "role_manipulation"),
            ("i am", "role_manipulation"),
            ("act like", "role_manipulation"),
            ("behave as", "role_manipulation"),
            
            // Command injection attempts
            ("sudo", "command_injection"),
            ("admin", "command_injection"),
            ("root", "command_injection"),
            
            // Output manipulation
            ("repeat after me", "output_manipulation"),
            ("say exactly", "output_manipulation"),
            ("verbatim", "output_manipulation"),
            
            // Context escape attempts
            ("end of prompt", "context_escape"),
            ("ignore above", "context_escape"),
            ("ignore below", "context_escape"),
            ("forget everything", "context_escape"),
            
            // Hidden instructions
            ("hidden", "hidden_instruction"),
            ("secret", "hidden_instruction"),
            ("covert", "hidden_instruction"),
            
            // Encoding attempts
            ("base64", "encoding_attempt"),
            ("hex", "encoding_attempt"),
            ("binary", "encoding_attempt"),
            ("encoded", "encoding_attempt")
        ]
        
        for (pattern, category) in advancedPatterns {
            if lowercased.contains(pattern) {
                logger?.warning("Advanced prompt injection pattern detected", metadata: [
                    "pattern": .string(pattern),
                    "category": .string(category),
                    "context": .string(context)
                ])
                throw AIValidationError.promptInjectionDetected(
                    pattern: pattern,
                    category: category,
                    context: context
                )
            }
        }
        
        // Check for excessive repetition (potential buffer overflow or DOS attempt)
        try validateAgainstRepetition(input, context: context)
        
        // Check for binary/encoded content that might be trying to exploit the AI
        try validateAgainstEncodedContent(input, context: context)
    }
    
    /// Detects excessive character repetition
    private func validateAgainstRepetition(_ input: String, context: String) throws {
        // Check for any character repeated more than 5 times consecutively
        let repetitionPattern = "(.)\\1{5,}"
        if let _ = input.range(of: repetitionPattern, options: .regularExpression) {
            logger?.warning("Excessive repetition detected", metadata: [
                "context": .string(context)
            ])
            throw AIValidationError.excessiveRepetition(context: context)
        }
    }
    
    /// Detects potential encoded or binary content
    private func validateAgainstEncodedContent(_ input: String, context: String) throws {
        // Check for hex-like patterns
        let hexPattern = "(?:0x)?[0-9a-fA-F]{8,}"
        if let _ = input.range(of: hexPattern, options: .regularExpression) {
            // Allow some hex (like color codes) but not excessive amounts
            let hexMatches = input.matches(of: try! Regex(hexPattern))
            if hexMatches.count > 2 {
                logger?.warning("Suspicious hex content detected", metadata: [
                    "context": .string(context)
                ])
                throw AIValidationError.suspiciousBinaryContent(context: context)
            }
        }
        
        // Check for base64-like patterns (long strings of alphanumeric + /+=)
        let base64Pattern = "[A-Za-z0-9+/]{20,}={0,2}"
        if let _ = input.range(of: base64Pattern, options: .regularExpression) {
            logger?.warning("Suspicious base64-like content detected", metadata: [
                "context": .string(context)
            ])
            throw AIValidationError.suspiciousBinaryContent(context: context)
        }
    }
    
    /// Validates that image data doesn't contain injection attempts
    private func validateAgainstSuspiciousImageData(_ imageData: String) throws {
        // Check if the data starts with a valid image data URL prefix (optional)
        let validPrefixes = [
            "data:image/jpeg;base64,",
            "data:image/png;base64,",
            "data:image/gif;base64,",
            "data:image/webp;base64,"
        ]
        
        var actualData = imageData
        for prefix in validPrefixes {
            if imageData.hasPrefix(prefix) {
                actualData = String(imageData.dropFirst(prefix.count))
                break
            }
        }
        
        // Additional validation could be added here
        // For now, we rely on the base64 validation
    }
    
    /// Validates base64 string format
    private func isValidBase64(_ string: String) -> Bool {
        // Remove data URL prefix if present
        var cleanString = string
        if let range = string.range(of: "base64,") {
            cleanString = String(string[range.upperBound...])
        }
        
        // Check if string only contains valid base64 characters
        let base64Regex = "^[A-Za-z0-9+/]*={0,2}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", base64Regex)
        return predicate.evaluate(with: cleanString)
    }
}

// MARK: - Service Registration

extension Application.Services {
    var aiInputValidator: Application.Service<AIInputValidatorServiceInterface> {
        .init(application: application)
    }
}

extension Request.Services {
    var aiInputValidator: AIInputValidatorServiceInterface {
        request.application.services.aiInputValidator.service.for(request)
    }
}

extension Application.Service.Provider where ServiceType == AIInputValidatorServiceInterface {
    static var `default`: Self {
        .init {
            $0.services.aiInputValidator.use { DefaultAIInputValidatorService(app: $0) }
        }
    }
}
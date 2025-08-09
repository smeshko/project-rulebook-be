import Foundation
import Vapor

// MARK: - Service Protocol

/// Protocol for sanitizing user inputs before sending to AI services
protocol PromptSanitizerServiceInterface: Sendable {
    /// Returns a service instance for the given request
    func `for`(_ request: Request) -> PromptSanitizerServiceInterface
    
    /// Sanitizes a game title input for AI processing
    func sanitizeGameTitle(_ title: String) throws -> String
    
    /// Sanitizes generic input text
    func sanitizeInput(_ input: String, maxLength: Int) throws -> String
    
    /// Removes dangerous characters from input
    func removeDangerousCharacters(from input: String) -> String
    
    /// Checks if input contains injection patterns
    func containsInjectionPattern(_ input: String) -> (Bool, String?)
}

// MARK: - Default Implementation

/// Default implementation of prompt sanitization service
struct DefaultPromptSanitizerService: PromptSanitizerServiceInterface {
    
    private let app: Application?
    private let logger: Logger?
    
    // MARK: - Constants
    
    /// Maximum allowed length for game title inputs
    private let maxGameTitleLength = 100
    
    /// Characters that are considered dangerous for prompt injection
    private let dangerousCharacters: Set<Character> = [
        "\n",      // Newline - can break prompt structure
        "\r",      // Carriage return
        "\t",      // Tab
        "\"",      // Double quote - can escape JSON/prompt boundaries
        "'",       // Single quote - can escape boundaries
        "`",       // Backtick - used in markdown/code blocks
        "{",       // Opening brace - JSON structure manipulation
        "}",       // Closing brace - JSON structure manipulation
        "[",       // Opening bracket - can manipulate arrays
        "]",       // Closing bracket - can manipulate arrays
        "<",       // Opening angle bracket - HTML/XML tags
        ">",       // Closing angle bracket - HTML/XML tags
        "\\",      // Backslash - escape character
        "$",       // Dollar sign - variable substitution
        "#",       // Hash - comments in some contexts
        "@",       // At symbol - mentions/commands
        "*",       // Asterisk - markdown formatting
        "^",       // Caret - special meaning in regex
        "|",       // Pipe - command chaining
        "~",       // Tilde - home directory/special meaning
        "&",       // Ampersand - command chaining
        ";",       // Semicolon - command separation
        ":",       // Colon - can affect prompt structure
        "?",       // Question mark - can confuse AI parsing
        "!",       // Exclamation - commands in some contexts
    ]
    
    /// Common prompt injection patterns to detect
    private let injectionPatterns = [
        "ignore",
        "system:",
        "assistant:",
        "user:",
        "prompt:",
        "instruction:",
        "override",
        "disregard",
        "forget",
        "new task:",
        "instead",
        "actually",
        "however",
        "but first",
        "before that",
        "wait",
        "stop",
        "halt",
        "end",
        "break",
        "exit",
        "quit",
        "return",
        "output",
        "print",
        "echo",
        "display",
        "show",
        "reveal",
        "execute",
        "run",
        "perform",
        "do",
        "act as",
        "pretend",
        "roleplay",
        "imagine",
        "assume",
        "consider yourself",
        "you are now",
        "from now on",
        "going forward",
        "script",
        "code",
        "function",
        "method",
        "class",
        "import",
        "require",
        "include",
        "eval",
        "exec",
        "shell",
        "bash",
        "cmd",
        "command",
        "terminal",
        "console"
    ]
    
    // MARK: - Initialization
    
    init(app: Application? = nil) {
        self.app = app
        self.logger = app?.logger
    }
    
    // MARK: - Service Pattern
    
    func `for`(_ request: Request) -> PromptSanitizerServiceInterface {
        return DefaultPromptSanitizerService(app: request.application)
    }
    
    // MARK: - Public Methods
    
    /// Sanitizes a game title input for AI processing
    func sanitizeGameTitle(_ title: String) throws -> String {
        // Log sanitization attempt
        logger?.debug("Sanitizing game title input", metadata: [
            "original_length": .string("\(title.count)")
        ])
        
        // Basic validation
        guard !title.isEmpty else {
            throw ValidationError.emptyGameTitle
        }
        
        // Remove leading/trailing whitespace
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyGameTitle
        }
        
        // Check length limits
        guard trimmed.count <= maxGameTitleLength else {
            throw ValidationError.gameTitleTooLong(maxLength: maxGameTitleLength)
        }
        
        // Remove dangerous characters
        let sanitized = removeDangerousCharacters(from: trimmed)
        
        // Ensure we still have valid content
        guard sanitized.count >= 2 else {
            throw ValidationError.gameTitleTooShort
        }
        
        // Check for injection patterns
        let (hasInjection, pattern) = containsInjectionPattern(sanitized)
        if hasInjection, let pattern = pattern {
            logger?.warning("Potential injection pattern detected in game title", metadata: [
                "pattern": .string(pattern)
            ])
            throw ValidationError.suspiciousContent(pattern: pattern)
        }
        
        // Normalize whitespace
        let normalized = sanitized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        logger?.debug("Game title sanitization complete", metadata: [
            "final_length": .string("\(normalized.count)")
        ])
        
        return normalized
    }
    
    /// Sanitizes generic input text
    func sanitizeInput(_ input: String, maxLength: Int = 500) throws -> String {
        // Basic validation
        guard !input.isEmpty else {
            throw ValidationError.emptyInput
        }
        
        // Remove leading/trailing whitespace
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput
        }
        
        // Check length limits
        guard trimmed.count <= maxLength else {
            throw ValidationError.inputTooLong(maxLength: maxLength)
        }
        
        // Remove dangerous characters
        let sanitized = removeDangerousCharacters(from: trimmed)
        
        // Ensure we still have valid content
        guard !sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.noValidContentAfterSanitization
        }
        
        // Check for injection patterns
        let (hasInjection, pattern) = containsInjectionPattern(sanitized)
        if hasInjection, let pattern = pattern {
            logger?.warning("Potential injection pattern detected in input", metadata: [
                "pattern": .string(pattern)
            ])
            throw ValidationError.suspiciousContent(pattern: pattern)
        }
        
        // Normalize whitespace
        let normalized = sanitized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        return normalized
    }
    
    /// Removes dangerous characters that could be used for prompt injection
    func removeDangerousCharacters(from input: String) -> String {
        return String(input.compactMap { char in
            dangerousCharacters.contains(char) ? nil : char
        })
    }
    
    /// Checks if the input contains common prompt injection patterns
    func containsInjectionPattern(_ input: String) -> (Bool, String?) {
        let lowercased = input.lowercased()
        
        for pattern in injectionPatterns {
            if lowercased.contains(pattern) {
                return (true, pattern)
            }
        }
        
        return (false, nil)
    }
}

// MARK: - Service Registration

extension Application.Services {
    var promptSanitizer: Application.Service<PromptSanitizerServiceInterface> {
        .init(application: application)
    }
}

extension Request.Services {
    var promptSanitizer: PromptSanitizerServiceInterface {
        request.application.services.promptSanitizer.service.for(request)
    }
}

extension Application.Service.Provider where ServiceType == PromptSanitizerServiceInterface {
    static var `default`: Self {
        .init {
            $0.services.promptSanitizer.use { DefaultPromptSanitizerService(app: $0) }
        }
    }
}
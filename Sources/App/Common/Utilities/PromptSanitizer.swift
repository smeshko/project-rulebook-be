import Foundation

/// Utility for sanitizing user inputs before sending to AI services to prevent prompt injection attacks
struct PromptSanitizer {
    
    // MARK: - Constants
    
    /// Maximum allowed length for game title inputs
    static let maxGameTitleLength = 100
    
    /// Characters that are considered dangerous for prompt injection
    private static let dangerousCharacters: Set<Character> = [
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
    private static let injectionPatterns = [
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
    
    // MARK: - Public Methods
    
    /// Sanitizes a game title input to prevent prompt injection while preserving legitimate game names
    /// - Parameter gameTitle: The raw game title input from user
    /// - Returns: Sanitized game title safe for AI prompts
    /// - Throws: `ValidationError` if input is invalid or potentially malicious
    static func sanitizeGameTitle(_ gameTitle: String) throws -> String {
        // Remove leading/trailing whitespace
        let trimmed = gameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty input
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyGameTitle
        }
        
        // Check length limit
        guard trimmed.count <= maxGameTitleLength else {
            throw ValidationError.gameTitleTooLong(maxLength: maxGameTitleLength)
        }
        
        // Remove control characters (but preserve normal spaces)
        let controlCharactersRemoved = trimmed.filter { char in
            char.isASCII && (char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation) || char == " "
        }
        
        // Check for injection patterns
        let lowercased = controlCharactersRemoved.lowercased()
        for pattern in injectionPatterns {
            if lowercased.contains(pattern) {
                throw ValidationError.suspiciousContent(pattern: pattern)
            }
        }
        
        // Sanitize dangerous characters by replacing with safe equivalents or removing
        let sanitized = controlCharactersRemoved.map { char in
            sanitizeCharacter(char)
        }.joined()
        
        // Final validation - ensure we still have meaningful content
        let finalTrimmed = sanitized.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !finalTrimmed.isEmpty else {
            throw ValidationError.noValidContentAfterSanitization
        }
        
        // Ensure the result is still reasonable length
        guard finalTrimmed.count >= 2 else {
            throw ValidationError.gameTitleTooShort
        }
        
        return finalTrimmed
    }
    
    /// Sanitizes general text input for AI prompts
    /// - Parameter text: The raw text input
    /// - Parameter maxLength: Maximum allowed length (default: 500)
    /// - Returns: Sanitized text safe for AI prompts
    /// - Throws: `ValidationError` if input is invalid
    static func sanitizeTextInput(_ text: String, maxLength: Int = 500) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            throw ValidationError.emptyInput
        }
        
        guard trimmed.count <= maxLength else {
            throw ValidationError.inputTooLong(maxLength: maxLength)
        }
        
        // Remove control characters
        let controlCharactersRemoved = trimmed.filter { char in
            char.isASCII && (char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation) || char == " "
        }
        
        // Sanitize dangerous characters
        let sanitized = controlCharactersRemoved.map { char in
            sanitizeCharacter(char)
        }.joined()
        
        return sanitized.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    // MARK: - Private Methods
    
    /// Sanitizes individual characters by replacing dangerous ones with safe equivalents
    /// - Parameter char: Character to sanitize
    /// - Returns: Safe replacement character or empty string if character should be removed
    private static func sanitizeCharacter(_ char: Character) -> String {
        if dangerousCharacters.contains(char) {
            switch char {
            case "\"", "'", "`":
                return "'" // Replace quotes with safe single quote
            case "{", "}", "[", "]", "<", ">":
                return "" // Remove structural characters entirely
            case "\n", "\r", "\t":
                return " " // Replace with space
            case "\\", "$", "#", "@", "*", "^", "|", "~", "&", ";":
                return "" // Remove special characters
            case ":", "?", "!":
                return char == ":" ? "" : "" // Remove command-like punctuation
            default:
                return "" // Remove any other dangerous characters
            }
        }
        return String(char)
    }
}

// MARK: - Validation Errors

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
            return "Input contains potentially malicious content: '\(pattern)'"
        case .noValidContentAfterSanitization:
            return "No valid content remains after security sanitization"
        }
    }
}
import Vapor
import Foundation

/// Response model for Google Gemini generateContent API.
///
/// Provides decoding for the nested candidates/content/parts structure and
/// a helper to extract primary text content.
struct GeminiResponse: Content {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
            }
            let parts: [Part]
            let role: String?
        }

        let content: Content
        let finishReason: String
        let index: Int
    }

    struct UsageMetadata: Codable {
        struct TokenDetails: Codable {
            let modality: String
            let tokenCount: Int
        }

        let promptTokenCount: Int
        let candidatesTokenCount: Int
        let totalTokenCount: Int
        let promptTokensDetails: [TokenDetails]?
        let toolUsePromptTokenCount: Int?
        let toolUsePromptTokensDetails: [TokenDetails]?
        let thoughtsTokenCount: Int?
    }

    let candidates: [Candidate]
    let usageMetadata: UsageMetadata?
    let modelVersion: String?
    let responseId: String?
}

extension GeminiResponse {
    /// Extracts primary text content from the first candidate's first part.
    func extractText() -> String? {
        guard let firstCandidate = candidates.first else { return nil }
        // Concatenate parts' text when multiple exist
        let texts = firstCandidate.content.parts.compactMap { $0.text?.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard !texts.isEmpty else { return nil }

        // If the content is wrapped in code fences, strip them and clean markdown
        let combined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        // First remove common ```json fences for backwards compatibility
        let unfenced = GeminiResponse.cleanJSONMarkdown(combined)
        // If it looks like JSON after trimming, return as is to avoid altering JSON content
        let trimmed = unfenced.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") { return trimmed }
        // Otherwise, strip general Markdown formatting to return plain text
        return GeminiResponse.stripMarkdown(unfenced)
    }

    private static func cleanJSONMarkdown(_ input: String) -> String {
        var s = input
        if s.hasPrefix("```json") || s.hasPrefix("```JSON") {
            s = s.replacingOccurrences(of: "```json", with: "")
            s = s.replacingOccurrences(of: "```JSON", with: "")
            if let range = s.range(of: "```", options: [.backwards]) {
                s.removeSubrange(range)
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Strips common Markdown constructs to produce plain text.
    private static func stripMarkdown(_ input: String) -> String {
        var output = input

        func regexReplace(_ pattern: String, _ template: String, options: NSRegularExpression.Options = []) -> String {
            guard let re = try? NSRegularExpression(pattern: pattern, options: options) else { return output }
            let range = NSRange(location: 0, length: (output as NSString).length)
            return re.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: template)
        }

        // 1) Code fences ```lang ... ``` -> keep inner content
        output = regexReplace("```[a-zA-Z0-9_-]*\\s*([\\s\\S]*?)\\s*```", "$1", options: [.dotMatchesLineSeparators])
        // 2) Inline code `code` -> code
        output = regexReplace("`([^`]*)`", "$1")
        // 3) Images ![alt](url) -> alt
        output = regexReplace("!\\[([^\\]]*)\\]\\([^\\)]*\\)", "$1")
        // 4) Links [text](url) -> text
        output = regexReplace("\\[([^\\]]+)\\]\\([^\\)]+\\)", "$1")
        // 5) Headers ### Title -> Title
        output = regexReplace("(?m)^[ \\t]*#{1,6}[ \\t]+", "")
        // 6) Blockquotes > text -> text
        output = regexReplace("(?m)^[ \\t]*>+[ \\t]?", "")
        // 7) Lists - item / * item / + item / 1. item -> item
        output = regexReplace("(?m)^[ \\t]*([\\-*+]|[0-9]+\\.)[ \\t]+", "")
        // 8) Bold/italic markers **text** -> text, *text* -> text, __text__ -> text, _text_ -> text
        output = regexReplace("\\*\\*([^*]+)\\*\\*", "$1")
        output = regexReplace("__([^_]+)__", "$1")
        output = regexReplace("\\*([^*]+)\\*", "$1")
        output = regexReplace("_([^_]+)_", "$1")
        // 9) Horizontal rules (---, ***, ___) lines -> remove
        output = regexReplace("(?m)^[ \\t]*([-*_]){3,}[ \\t]*$\\n?", "")
        // 10) Remove stray backticks
        output = output.replacingOccurrences(of: "`", with: "")
        // 11) Normalize spacing: trim lines and collapse excess blank lines
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        var collapsed: [String] = []
        var blankCount = 0
        for line in lines {
            if line.isEmpty {
                blankCount += 1
                if blankCount <= 1 { collapsed.append("") }
            } else {
                blankCount = 0
                collapsed.append(line)
            }
        }
        output = collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        return output
    }
}

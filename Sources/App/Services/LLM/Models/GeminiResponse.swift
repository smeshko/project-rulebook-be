import Vapor

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

        // If the content is wrapped in ```json ... ```, strip the fences
        let combined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return GeminiResponse.cleanJSONMarkdown(combined)
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
}


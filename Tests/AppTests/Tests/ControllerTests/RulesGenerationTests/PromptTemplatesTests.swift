import Testing
@testable import App

@Suite("PromptTemplates Tests")
struct PromptTemplatesTests {

    // MARK: - GameBoxAnalysis

    @Suite("GameBoxAnalysis Prompts")
    struct GameBoxAnalysisTests {

        @Test("System prompt is non-empty")
        func systemPromptIsNonEmpty() {
            let prompt = PromptTemplates.GameBoxAnalysis.systemPrompt
            #expect(!prompt.isEmpty)
        }

        @Test("System prompt requests JSON-only output")
        func systemPromptRequestsJSON() {
            let prompt = PromptTemplates.GameBoxAnalysis.systemPrompt
            #expect(prompt.contains("JSON"))
        }

        @Test("System prompt includes required response fields")
        func systemPromptIncludesRequiredFields() {
            let prompt = PromptTemplates.GameBoxAnalysis.systemPrompt
            #expect(prompt.contains("guessedTitle"))
            #expect(prompt.contains("confidence"))
            #expect(prompt.contains("alternativeTitles"))
            #expect(prompt.contains("keywordsDetected"))
            #expect(prompt.contains("notes"))
        }

        @Test("System prompt is shorter than original inline prompt")
        func systemPromptIsOptimized() {
            let prompt = PromptTemplates.GameBoxAnalysis.systemPrompt
            // Original was ~26 lines / ~483 words. Optimized should be significantly shorter.
            let originalApproxCharCount = 1100
            #expect(prompt.count < originalApproxCharCount, "Optimized prompt should be shorter than original")
        }
    }

    // MARK: - RulesGeneration

    @Suite("RulesGeneration Prompts")
    struct RulesGenerationTests {

        @Test("System prompt is non-empty")
        func systemPromptIsNonEmpty() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(!prompt.isEmpty)
        }

        @Test("System prompt requests JSON-only output")
        func systemPromptRequestsJSON() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("JSON"))
        }

        @Test("System prompt includes all required response fields")
        func systemPromptIncludesRequiredFields() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("title"))
            #expect(prompt.contains("playerCount"))
            #expect(prompt.contains("playTime"))
            #expect(prompt.contains("summary"))
            #expect(prompt.contains("initialSetup"))
            #expect(prompt.contains("firstRoundGuide"))
            #expect(prompt.contains("winCondition"))
            #expect(prompt.contains("deepDive"))
            #expect(prompt.contains("resources"))
            #expect(prompt.contains("confidence"))
            #expect(prompt.contains("notes"))
        }

        @Test("User prompt includes game title")
        func userPromptIncludesGameTitle() {
            let prompt = PromptTemplates.RulesGeneration.userPrompt(gameTitle: "Catan")
            #expect(prompt.contains("Catan"))
        }

        @Test("User prompt format is concise")
        func userPromptFormatIsConcise() {
            let prompt = PromptTemplates.RulesGeneration.userPrompt(gameTitle: "Chess")
            #expect(prompt == "Game: Chess")
        }

        @Test("System prompt is shorter than original inline prompt")
        func systemPromptIsOptimized() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            // Original was ~43 lines / ~297 words. Optimized should be significantly shorter.
            let originalApproxCharCount = 1700
            #expect(prompt.count < originalApproxCharCount, "Optimized prompt should be shorter than original")
        }
    }
}

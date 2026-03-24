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
    }

    // MARK: - RulesGeneration

    @Suite("RulesGeneration Prompts")
    struct RulesGenerationTests {

        @Test("System prompt is non-empty")
        func systemPromptIsNonEmpty() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(!prompt.isEmpty)
        }

        @Test("System prompt includes web search instructions")
        func systemPromptIncludesWebSearch() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("BoardGameGeek"))
            #expect(prompt.contains("web search"))
            #expect(prompt.contains("rulebook"))
        }

        @Test("System prompt includes accuracy rules")
        func systemPromptIncludesAccuracyRules() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("recurring phases"))
            #expect(prompt.contains("Never invent"))
            #expect(prompt.contains("BGG weight"))
        }

        @Test("System prompt includes structure enums")
        func systemPromptIncludesStructureEnums() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("chooseOne"))
            #expect(prompt.contains("sequential"))
            #expect(prompt.contains("actionPoints"))
            #expect(prompt.contains("simultaneous"))
            #expect(prompt.contains("gameBreaking"))
            #expect(prompt.contains("SF Symbol"))
        }

        @Test("System prompt includes key structured output fields")
        func systemPromptIncludesKeyFields() {
            let prompt = PromptTemplates.RulesGeneration.systemPrompt
            #expect(prompt.contains("turnStructure"))
            #expect(prompt.contains("complexity"))
            #expect(prompt.contains("mechanics"))
            #expect(prompt.contains("component"))
            #expect(prompt.contains("commonMistakes"))
        }

        @Test("User prompt includes game title")
        func userPromptIncludesGameTitle() {
            let prompt = PromptTemplates.RulesGeneration.userPrompt(gameTitle: "Catan")
            #expect(prompt.contains("Catan"))
        }

        @Test("User prompt instructs web search")
        func userPromptIncludesSearchInstruction() {
            let prompt = PromptTemplates.RulesGeneration.userPrompt(gameTitle: "Chess")
            #expect(prompt.contains("Search for"))
            #expect(prompt.contains("BoardGameGeek"))
        }
    }
}

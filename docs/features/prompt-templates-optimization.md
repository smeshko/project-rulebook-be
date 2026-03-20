# AI Prompt Templates & Optimization

**Date:** 2026-03-20
**Related Files:** `Sources/App/Modules/RulesGeneration/Prompts/PromptTemplates.swift`, `Sources/App/Modules/RulesGeneration/Controller/RulesGenerationController.swift`

## Overview

Extracted and optimized all AI prompts from inline string literals in `RulesGenerationController` into a dedicated `PromptTemplates` module. Prompts were restructured to reduce token count (~40% reduction) while preserving output quality and JSON schema compatibility with existing validators.

## What Was Built

- `PromptTemplates` enum with two namespaces: `GameBoxAnalysis` and `RulesGeneration`
- Optimized system prompts with reduced token counts
- `userPrompt(gameTitle:)` factory method for rules generation
- 10 unit tests covering prompt content, required fields, and optimization targets

## Technical Implementation

### Key Files

- `Sources/App/Modules/RulesGeneration/Prompts/PromptTemplates.swift`: Contains all AI prompt templates as static properties organized by use case
- `Sources/App/Modules/RulesGeneration/Controller/RulesGenerationController.swift`: References `PromptTemplates` instead of inline strings
- `Tests/AppTests/Tests/ControllerTests/RulesGenerationTests/PromptTemplatesTests.swift`: Unit tests for prompt content and optimization

### Key Patterns

- **Prompt-as-module pattern**: All LLM prompts live in `PromptTemplates` enum namespaces, not inline in controllers. Each namespace exposes a `systemPrompt` static property and optional `userPrompt(...)` method. New AI features should add a new namespace here.
- **Token optimization techniques**: Imperative instructions replace conversational phrasing; JSON schema placed early to reduce attention overhead; redundant instructions consolidated; positive directives replace negative ones.
- **Schema preservation**: JSON field names in prompts must exactly match the Codable struct properties (`RulesSummary.Response`, validator fields). Changing field names will break `AIResponseValidationService`.

### Code Examples

```swift
// Adding a new prompt namespace to PromptTemplates
enum PromptTemplates {
    enum NewFeature {
        static let systemPrompt = """
            [Concise system instructions]
            Respond with ONLY a JSON object. No markdown, no explanation.
            { "field": "description" }
            """

        static func userPrompt(input: String) -> String {
            "Input: \(input)"
        }
    }
}
```

```swift
// Using prompts in a controller
let combinedPrompt = """
    \(PromptTemplates.RulesGeneration.systemPrompt)

    \(PromptTemplates.RulesGeneration.userPrompt(gameTitle: title))
    """
let response = try await llmService.generate(input: combinedPrompt)
```

## How to Use

1. To modify existing prompts, edit `PromptTemplates.swift` — run `PromptTemplatesTests` to verify field names are preserved
2. To add a new AI feature, create a new namespace in the `PromptTemplates` enum following the existing pattern
3. Always include a `Respond with ONLY a JSON object` directive for structured output
4. Run validators (`AIResponseValidationService`) against sample outputs after any prompt change

## Configuration

Prompts are compile-time constants (static `let` properties). To make prompts runtime-configurable in the future, convert to computed properties that read from a configuration source.

| Prompt | Original Size | Optimized Size | Reduction |
|--------|--------------|----------------|-----------|
| GameBoxAnalysis.systemPrompt | ~1100 chars | ~650 chars | ~41% |
| RulesGeneration.systemPrompt | ~1700 chars | ~1050 chars | ~38% |

## Notes

- Cache keys in `CacheKeyGeneratorService` are title-based, not prompt-based — prompt changes do not invalidate cache
- Both `GoogleGeminiService` and `OpenAIService` accept the optimized prompts without any service-level changes
- JSON field names are a contract with `AIResponseValidationService` — never rename without updating validators

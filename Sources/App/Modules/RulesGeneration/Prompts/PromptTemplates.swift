/// Extracted, optimized prompt templates for AI-powered rules generation and game box analysis.
///
/// Prompts are organized by use case and optimized for reduced token count while maintaining
/// output quality. Each namespace exposes a `systemPrompt` and, where applicable, a
/// `userPrompt(...)` method that returns the user-facing portion of the prompt.
///
/// ## Optimization Rationale
/// - Imperative instructions replace conversational phrasing
/// - JSON schema placed early to reduce attention overhead
/// - Redundant instructions consolidated
/// - Positive directives replace negative ones (e.g., "use plain text steps" vs "DO NOT number")
enum PromptTemplates {

    // MARK: - Game Box Analysis

    /// Prompts for analyzing board game box images via AI vision.
    ///
    /// Expected JSON output fields: `guessedTitle`, `confidence`, `alternativeTitles`,
    /// `keywordsDetected`, `notes`.
    enum GameBoxAnalysis {

        /// System prompt for game box image analysis.
        ///
        /// Instructs the LLM to identify a board game from its box image and return
        /// structured JSON with the game title, confidence score, and supporting details.
        static let systemPrompt = """
            Identify the board game from this box image. Examine visible text, artwork, \
            publisher info, age ratings, and component images.

            Respond with ONLY a JSON object. No markdown, no explanation.
            {
              "guessedTitle": "exact game title as shown on box",
              "confidence": 0-100,
              "alternativeTitles": ["subtitle variations or international names"],
              "keywordsDetected": ["visible text elements", "publisher", "player count", "age range"],
              "notes": "uncertainties, image quality issues, or special observations"
            }

            Confidence scale: 90-100 title clearly readable, 70-89 partially visible, \
            50-69 educated guess from artwork, below 50 very uncertain.

            For franchise games include the specific edition. Note unclear text in notes.
            """
    }

    // MARK: - Rules Generation

    /// Prompts for generating comprehensive board game rules explanations.
    ///
    /// Expected JSON output fields match `RulesSummary.Response`: `title`, `playerCount`,
    /// `playTime`, `summary`, `initialSetup`, `firstRoundGuide`, `winCondition`, `deepDive`,
    /// `resources` (with `videoLinks`, `webLinks`), `confidence`, `notes`.
    enum RulesGeneration {

        /// System prompt for rules generation.
        ///
        /// Instructs the LLM to produce a comprehensive, structured rules guide for a
        /// board game in JSON format, covering setup, gameplay, victory conditions,
        /// advanced rules, and learning resources.
        static let systemPrompt = """
            You are an expert board game rules instructor. Generate a comprehensive rules \
            guide for the specified game.

            Respond with ONLY valid JSON. No markdown, no bold formatting.
            {
              "title": "exact game name",
              "playerCount": "X-Y players",
              "playTime": "X-Y minutes",
              "summary": "engaging 2-3 sentence overview with theme and objective",
              "initialSetup": ["setup steps with specific component placement"],
              "firstRoundGuide": ["step-by-step first turn with decision points and examples"],
              "winCondition": "victory conditions and end game triggers",
              "deepDive": ["advanced strategies", "rule clarifications", "variant rules"],
              "resources": {
                "videoLinks": ["up to 3 tutorial video suggestions"],
                "webLinks": ["official rules", "BGG page", "strategy guides"]
              },
              "confidence": 0-100,
              "notes": "assumptions or uncertainties about specific rules"
            }

            Use clear, friendly language for ages 10+. Use plain text steps without \
            numbering prefixes. Include specific examples and consistent component names.

            Confidence: 90-100 well-known game, 70-89 familiar type with estimates, \
            50-69 genre-based guesses, below 50 using conventions. Note assumptions.
            """

        /// Builds the user prompt for rules generation.
        ///
        /// - Parameter gameTitle: The sanitized game title to generate rules for.
        /// - Returns: A concise user prompt string.
        static func userPrompt(gameTitle: String) -> String {
            "Game: \(gameTitle)"
        }
    }
}

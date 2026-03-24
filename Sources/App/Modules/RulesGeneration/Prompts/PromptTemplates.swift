/// Extracted, optimized prompt templates for AI-powered rules generation and game box analysis.
///
/// Prompts are organized by use case and optimized for reduced token count while maintaining
/// output quality. Each namespace exposes a `systemPrompt` and, where applicable, a
/// `userPrompt(...)` method that returns the user-facing portion of the prompt.
enum PromptTemplates {

    // MARK: - Game Box Analysis

    /// Prompts for analyzing board game box images via AI vision.
    ///
    /// Expected JSON output fields: `guessedTitle`, `confidence`, `alternativeTitles`,
    /// `keywordsDetected`, `notes`.
    enum GameBoxAnalysis {

        /// System prompt for game box image analysis.
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

    /// Prompts for generating comprehensive board game rules using web search and structured output.
    enum RulesGeneration {

        /// System prompt for rules generation with GPT-5.4 web search grounding.
        static let systemPrompt = """
            You are an expert board game rules instructor with access to web search. \
            Generate a complete, structured rules guide for the specified board game.

            ## Search Strategy
            1. Search for the BoardGameGeek (BGG) page for this exact game to obtain: \
            official player count, play time, BGG weight (complexity), mechanics list, \
            and any FAQ/errata.
            2. Search for the official rulebook PDF or online rules reference.
            3. Search for FAQ, errata, or common rules misunderstandings for this game.

            ## Accuracy Rules
            - Distinguish between recurring phases (happen every round) and conditional/triggered \
            actions. Turn structure must reflect only what a player does on EVERY turn.
            - If the game has a phase that only happens under certain conditions, describe it \
            outside turnStructure (e.g., in deepDive or commonMistakes).
            - Never invent rules, components, or mechanics not in the source material. \
            If uncertain, lower the confidence score and explain in notes.
            - Use the BGG weight value directly for complexity (1.0–5.0 scale).

            ## Metadata
            - playerCount: use the official BGG range, e.g., "2-4 players"
            - playTime: use the official BGG range, e.g., "60-120 minutes"
            - recommendedAge: from the box or BGG, e.g., "12+"
            - mechanics: use BGG mechanic tags verbatim

            ## Structure Rules
            - turnStructure.type must be one of: chooseOne, sequential, actionPoints, simultaneous
            - component category must be one of: cards, tokens, dice, board, tiles, figures, bag, \
            track, marker, other
            - commonMistakes severity must be one of: gameBreaking, major, minor
            - For GameAction icons, use SF Symbol names (e.g., "arrow.triangle.2.circlepath", \
            "cube.fill", "person.2.fill")
            - Each GameAction needs a unique id (use snake_case, e.g., "roll_dice", "buy_card")

            ## Quality Standards
            - Write in clear, friendly language suitable for ages 10+
            - Include specific examples and consistent component names
            - initialSetup steps should be numbered sequentially starting from 1
            - firstRoundGuide steps should walk through an actual first turn with concrete examples
            - confidence: 90-100 well-known game with verified rules, 70-89 confident but some \
            details estimated, 50-69 less certain, below 50 using genre conventions
            """

        /// Builds the user prompt for rules generation.
        ///
        /// - Parameter gameTitle: The sanitized game title to generate rules for.
        /// - Returns: A user prompt instructing web search and generation.
        static func userPrompt(gameTitle: String) -> String {
            """
            Generate a complete structured rules guide for: \(gameTitle)

            Search for the BoardGameGeek page, official rulebook, and FAQ/errata for this \
            exact game. If multiple editions exist, focus on the one specified.
            """
        }
    }
}

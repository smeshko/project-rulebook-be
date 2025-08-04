import Vapor

struct RulesGenerationController {

    func analyzeBoxPhoto(_ req: Request) async throws -> GameboxRecognition.Response {
        var data: Data?
        for try await part in req.body {
            if data == nil {
                data = Data(buffer: part)
            } else {
                data?.append(Data(buffer: part))
            }
        }

        guard let data else {
            throw ContentError.externalServiceFailedToRespond
        }
        let request = try JSONDecoder().decode(GameboxRecognition.Request.self, from: data)
        let encoded = request.image.base64EncodedString()
        let boxInput: [OpenAIRequest.Message] = [
            .init(
                role: "system",
                content: [
                    OpenAIRequest.Message.TextContent(
                        text:
                            "You are an assistant in a mobile app for board gamers. A user has taken a photo of a board game box.\n\nYour task is to analyze the image and identify which board game it is, using only your internal knowledge (you cannot access the web).\n\nReturn a JSON object with the following fields:\n\n{\n  \"guessedTitle\": \"Most likely game title\",\n  \"confidence\": \"Confidence from 0 to 100 (as a number)\",\n  \"alternativeTitles\": [\"Other possible matches, ranked by likelihood\"],\n  \"keywordsDetected\": [\"Any keywords or phrases you see on the box that helped you identify the game\"],\n  \"notes\": \"Any ambiguity or uncertainty about the match\"\n}\n\nRespond ONLY with valid JSON."
                    )
                ]
            ),
            .init(
                role: "user",
                content: [
                    OpenAIRequest.Message.ImageContent(
                        imageUrl: "data:image/png;base64,\(encoded)"
                    ),
                    OpenAIRequest.Message.TextContent(text: "Here is the image to analyze"),
                ]
            ),
        ]
        let boxResponse = try await req.services.llm.generate(input: boxInput)
        let boxBuffer = ByteBuffer(string: boxResponse)
        return try JSONDecoder().decode(GameboxRecognition.Response.self, from: boxBuffer)
    }

    func generateRulesSummary(_ req: Request) async throws -> RulesSummary.Response {
        let input = try req.content.decode(RulesSummary.Request.self)
        let rulesInput: [OpenAIRequest.Message] = [
            .init(
                role: "system",
                content: [
                    OpenAIRequest.Message.TextContent(
                        text:
                            "You are a helpful assistant embedded in a mobile app for board game players. A user has provided the name of a board game and wants to start playing immediately. Your task is to: 1. Find and understand the basic rules of the game (based on your internal knowledge and training data). 2. Summarize the game for first-time players. 3. Explain how to set up the game board and components in clear, numbered steps. 4. Suggest what each player should do during their first round to start the game smoothly. 5. Include a \\\"deep dive\\\" section with more detailed rules (e.g. phases, actions, key systems, or player strategies). 6. Provide helpful external links if known (e.g. to YouTube tutorials or official websites). 7. Return a confidence score (0–100) estimating how accurate and complete this information is. Respond ONLY in valid JSON using this structure: { \\\"title\\\": \\\"Game Name\\\", \\\"playerCount\\\": \\\"Number of players supported\\\", \\\"playTime\\\": \\\"Estimated play time\\\", \\\"summary\\\": \\\"Beginner-friendly overview of how the game works\\\", \\\"initialSetup\\\": [\\\"Step-by-step setup instructions\\\"], \\\"firstRoundGuide\\\": [\\\"Suggestions on what each player should do in the first round\\\"], \\\"winCondition\\\": \\\"How to win the game\\\", \\\"deepDive\\\": [\\\"Detailed rule explanations, phases, actions, special mechanics, strategies\\\"], \\\"resources\\\": { \\\"videoLinks\\\": [\\\"Optional YouTube or publisher video tutorials\\\"], \\\"webLinks\\\": [\\\"Optional helpful websites like BoardGameGeek, official rulebooks, etc.\\\"] }, \\\"confidence\\\": 0–100 (number), \\\"notes\\\": \\\"Any ambiguity or assumptions made\\\" } The JSON should be compact and contain only plain text values (no formatting). The game to summarize is: \(input.gameTitle)"
                    )
                ]
            )
        ]
        let rulesResponse = try await req.services.llm.generate(input: rulesInput)
        let rulesBuffer = ByteBuffer(string: rulesResponse)
        return try JSONDecoder().decode(RulesSummary.Response.self, from: rulesBuffer)
    }
}

/// OpenAI JSON schema for structured output in rules generation.
///
/// This schema enforces strict mode requirements:
/// - Every object has `additionalProperties: false`
/// - ALL properties listed in `required`
/// - Optional fields use `["string", "null"]` (or `["integer", "null"]`, `["boolean", "null"]`) type
enum RulesGenerationSchema {

    /// Returns the full JSON schema as a `JSONValue` for use in `TextConfig.FormatSpec.jsonSchema`.
    static let schema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("title"), .string("playerCount"), .string("playTime"),
            .string("complexity"), .string("recommendedAge"), .string("mechanics"),
            .string("summary"), .string("winCondition"), .string("endGameTrigger"),
            .string("scoringCategories"), .string("components"), .string("initialSetup"),
            .string("turnStructure"), .string("firstRoundGuide"), .string("glossary"),
            .string("deepDive"), .string("commonMistakes"), .string("quickReference"),
            .string("resources"), .string("confidence"), .string("notes"),
        ]),
        "properties": .object([
            "title": .object(["type": .string("string")]),
            "playerCount": .object(["type": .string("string")]),
            "playTime": .object(["type": .string("string")]),
            "complexity": .object(["type": .string("number")]),
            "recommendedAge": .object(["type": .string("string")]),
            "mechanics": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
            "summary": .object(["type": .string("string")]),
            "winCondition": .object(["type": .string("string")]),
            "endGameTrigger": .object(["type": .string("string")]),

            // scoringCategories
            "scoringCategories": .object([
                "type": .string("array"),
                "items": scoringCategorySchema,
            ]),

            // components
            "components": .object([
                "type": .string("array"),
                "items": componentSchema,
            ]),

            // initialSetup
            "initialSetup": .object([
                "type": .string("array"),
                "items": setupStepSchema,
            ]),

            // turnStructure
            "turnStructure": turnStructureSchema,

            // firstRoundGuide
            "firstRoundGuide": .object([
                "type": .string("array"),
                "items": guideStepSchema,
            ]),

            // glossary
            "glossary": .object([
                "type": .string("array"),
                "items": glossaryTermSchema,
            ]),

            // deepDive
            "deepDive": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),

            // commonMistakes
            "commonMistakes": .object([
                "type": .string("array"),
                "items": commonMistakeSchema,
            ]),

            // quickReference
            "quickReference": quickReferenceSchema,

            // resources
            "resources": resourcesSchema,

            "confidence": .object(["type": .string("integer")]),
            "notes": .object(["type": .string("string")]),
        ]),
    ])

    // MARK: - Sub-schemas

    private static let scoringCategorySchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("name"), .string("value"), .string("description")]),
        "properties": .object([
            "name": .object(["type": .string("string")]),
            "value": .object(["type": .string("string")]),
            "description": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let componentSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("name"), .string("quantity"), .string("category"), .string("description"),
        ]),
        "properties": .object([
            "name": .object(["type": .string("string")]),
            "quantity": .object(["type": .string("integer")]),
            "category": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("cards"), .string("tokens"), .string("dice"), .string("board"),
                    .string("tiles"), .string("figures"), .string("bag"), .string("track"),
                    .string("marker"), .string("other"),
                ]),
            ]),
            "description": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let setupStepSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("step"), .string("action"), .string("quantity"),
            .string("componentRef"), .string("isPerPlayer"),
            .string("warning"), .string("playerCountNote"),
        ]),
        "properties": .object([
            "step": .object(["type": .string("integer")]),
            "action": .object(["type": .string("string")]),
            "quantity": .object(["type": .array([.string("string"), .string("null")])]),
            "componentRef": .object(["type": .array([.string("string"), .string("null")])]),
            "isPerPlayer": .object(["type": .array([.string("boolean"), .string("null")])]),
            "warning": .object(["type": .array([.string("string"), .string("null")])]),
            "playerCountNote": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let gameActionSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("id"), .string("name"), .string("icon"),
            .string("description"), .string("cost"), .string("effect"),
        ]),
        "properties": .object([
            "id": .object(["type": .string("string")]),
            "name": .object(["type": .string("string")]),
            "icon": .object(["type": .string("string")]),
            "description": .object(["type": .string("string")]),
            "cost": .object(["type": .array([.string("string"), .string("null")])]),
            "effect": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let turnStructureSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("type"), .string("actions"), .string("endOfRoundAction")]),
        "properties": .object([
            "type": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("chooseOne"), .string("sequential"),
                    .string("actionPoints"), .string("simultaneous"),
                ]),
            ]),
            "actions": .object([
                "type": .string("array"),
                "items": gameActionSchema,
            ]),
            "endOfRoundAction": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let guideStepSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("step"), .string("description"),
            .string("title"), .string("actionRef"), .string("tip"),
        ]),
        "properties": .object([
            "step": .object(["type": .string("integer")]),
            "description": .object(["type": .string("string")]),
            "title": .object(["type": .array([.string("string"), .string("null")])]),
            "actionRef": .object(["type": .array([.string("string"), .string("null")])]),
            "tip": .object(["type": .array([.string("string"), .string("null")])]),
        ]),
    ])

    private static let glossaryTermSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("term"), .string("definition")]),
        "properties": .object([
            "term": .object(["type": .string("string")]),
            "definition": .object(["type": .string("string")]),
        ]),
    ])

    private static let commonMistakeSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("rule"), .string("mistake"), .string("correct"), .string("severity"),
        ]),
        "properties": .object([
            "rule": .object(["type": .string("string")]),
            "mistake": .object(["type": .string("string")]),
            "correct": .object(["type": .string("string")]),
            "severity": .object([
                "type": .string("string"),
                "enum": .array([
                    .string("gameBreaking"), .string("major"), .string("minor"),
                ]),
            ]),
        ]),
    ])

    private static let quickReferenceSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([
            .string("turnSummary"), .string("keyRules"),
            .string("scoringSummary"), .string("iconLegend"),
        ]),
        "properties": .object([
            "turnSummary": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
            "keyRules": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
            "scoringSummary": .object([
                "type": .array([.string("array"), .string("null")]),
                "items": scoringCategorySchema,
            ]),
            "iconLegend": .object([
                "type": .array([.string("array"), .string("null")]),
                "items": glossaryTermSchema,
            ]),
        ]),
    ])

    private static let resourcesSchema: JSONValue = .object([
        "type": .string("object"),
        "additionalProperties": .bool(false),
        "required": .array([.string("videoLinks"), .string("webLinks")]),
        "properties": .object([
            "videoLinks": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
            "webLinks": .object([
                "type": .string("array"),
                "items": .object(["type": .string("string")]),
            ]),
        ]),
    ])
}

import Foundation

public enum RulesSummary {}

extension RulesSummary {
    public struct Request: Codable, Equatable, Sendable {
        public let gameTitle: String

        public init(gameTitle: String) {
            self.gameTitle = gameTitle
        }
    }

    public struct Response: Codable, Equatable, Sendable {

        // MARK: - Nested Types

        public struct GameResources: Codable, Equatable, Sendable {
            public let videoLinks: [String]
            public let webLinks: [String]

            public init(videoLinks: [String], webLinks: [String]) {
                self.videoLinks = videoLinks
                self.webLinks = webLinks
            }
        }

        public struct ScoringCategory: Codable, Equatable, Sendable {
            public let name: String
            public let value: String
            public let description: String?

            public init(name: String, value: String, description: String? = nil) {
                self.name = name
                self.value = value
                self.description = description
            }
        }

        public enum ComponentCategory: String, Codable, Equatable, Sendable {
            case cards, tokens, dice, board, tiles, figures, bag, track, marker, other
        }

        public struct Component: Codable, Equatable, Sendable {
            public let name: String
            public let quantity: Int
            public let category: ComponentCategory
            public let description: String?

            public init(name: String, quantity: Int, category: ComponentCategory, description: String? = nil) {
                self.name = name
                self.quantity = quantity
                self.category = category
                self.description = description
            }
        }

        public struct SetupStep: Codable, Equatable, Sendable {
            public let step: Int
            public let action: String
            public let quantity: String?
            public let componentRef: String?
            public let isPerPlayer: Bool?
            public let warning: String?
            public let playerCountNote: String?

            public init(
                step: Int,
                action: String,
                quantity: String? = nil,
                componentRef: String? = nil,
                isPerPlayer: Bool? = nil,
                warning: String? = nil,
                playerCountNote: String? = nil
            ) {
                self.step = step
                self.action = action
                self.quantity = quantity
                self.componentRef = componentRef
                self.isPerPlayer = isPerPlayer
                self.warning = warning
                self.playerCountNote = playerCountNote
            }
        }

        public enum TurnType: String, Codable, Equatable, Sendable {
            case chooseOne, sequential, actionPoints, simultaneous
        }

        public struct GameAction: Codable, Equatable, Sendable {
            public let id: String
            public let name: String
            public let icon: String
            public let description: String
            public let cost: String?
            public let effect: String?

            public init(
                id: String, name: String, icon: String, description: String,
                cost: String? = nil, effect: String? = nil
            ) {
                self.id = id
                self.name = name
                self.icon = icon
                self.description = description
                self.cost = cost
                self.effect = effect
            }
        }

        public struct TurnStructure: Codable, Equatable, Sendable {
            public let type: TurnType
            public let actions: [GameAction]
            public let endOfRoundAction: String?

            public init(type: TurnType, actions: [GameAction], endOfRoundAction: String? = nil) {
                self.type = type
                self.actions = actions
                self.endOfRoundAction = endOfRoundAction
            }
        }

        public struct GuideStep: Codable, Equatable, Sendable {
            public let step: Int
            public let description: String
            public let title: String?
            public let actionRef: String?
            public let tip: String?

            public init(
                step: Int, description: String,
                title: String? = nil, actionRef: String? = nil, tip: String? = nil
            ) {
                self.step = step
                self.description = description
                self.title = title
                self.actionRef = actionRef
                self.tip = tip
            }
        }

        public struct GlossaryTerm: Codable, Equatable, Sendable {
            public let term: String
            public let definition: String

            public init(term: String, definition: String) {
                self.term = term
                self.definition = definition
            }
        }

        public enum MistakeSeverity: String, Codable, Equatable, Sendable {
            case gameBreaking, major, minor
        }

        public struct CommonMistake: Codable, Equatable, Sendable {
            public let rule: String
            public let mistake: String
            public let correct: String
            public let severity: MistakeSeverity

            public init(rule: String, mistake: String, correct: String, severity: MistakeSeverity) {
                self.rule = rule
                self.mistake = mistake
                self.correct = correct
                self.severity = severity
            }
        }

        public struct QuickReference: Codable, Equatable, Sendable {
            public let turnSummary: [String]
            public let keyRules: [String]
            public let scoringSummary: [ScoringCategory]?
            public let iconLegend: [GlossaryTerm]?

            public init(
                turnSummary: [String], keyRules: [String],
                scoringSummary: [ScoringCategory]? = nil, iconLegend: [GlossaryTerm]? = nil
            ) {
                self.turnSummary = turnSummary
                self.keyRules = keyRules
                self.scoringSummary = scoringSummary
                self.iconLegend = iconLegend
            }
        }

        // MARK: - Response Fields

        public let title: String
        public let playerCount: String
        public let playTime: String
        public let complexity: Double
        public let recommendedAge: String
        public let mechanics: [String]
        public let summary: String
        public let winCondition: String
        public let endGameTrigger: String
        public let scoringCategories: [ScoringCategory]
        public let components: [Component]
        public let initialSetup: [SetupStep]
        public let turnStructure: TurnStructure
        public let firstRoundGuide: [GuideStep]
        public let glossary: [GlossaryTerm]
        public let deepDive: [String]
        public let commonMistakes: [CommonMistake]
        public let quickReference: QuickReference
        public let resources: GameResources
        public let confidence: Int
        public let notes: String

        public init(
            title: String,
            playerCount: String,
            playTime: String,
            complexity: Double,
            recommendedAge: String,
            mechanics: [String],
            summary: String,
            winCondition: String,
            endGameTrigger: String,
            scoringCategories: [ScoringCategory],
            components: [Component],
            initialSetup: [SetupStep],
            turnStructure: TurnStructure,
            firstRoundGuide: [GuideStep],
            glossary: [GlossaryTerm],
            deepDive: [String],
            commonMistakes: [CommonMistake],
            quickReference: QuickReference,
            resources: GameResources,
            confidence: Int,
            notes: String
        ) {
            self.title = title
            self.playerCount = playerCount
            self.playTime = playTime
            self.complexity = complexity
            self.recommendedAge = recommendedAge
            self.mechanics = mechanics
            self.summary = summary
            self.winCondition = winCondition
            self.endGameTrigger = endGameTrigger
            self.scoringCategories = scoringCategories
            self.components = components
            self.initialSetup = initialSetup
            self.turnStructure = turnStructure
            self.firstRoundGuide = firstRoundGuide
            self.glossary = glossary
            self.deepDive = deepDive
            self.commonMistakes = commonMistakes
            self.quickReference = quickReference
            self.resources = resources
            self.confidence = confidence
            self.notes = notes
        }
    }
}

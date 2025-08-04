import Foundation

public enum RulesSummary {}

extension RulesSummary {
    public struct Request: Codable, Equatable, Sendable {
        public let gameTitle: String
        
        init(gameTitle: String) {
            self.gameTitle = gameTitle
        }
    }
    
    public struct Response: Codable, Equatable, Sendable {
        public struct GameResources: Codable, Equatable, Sendable {
            public let videoLinks: [String]
            public let webLinks: [String]
            
            public init(
                videoLinks: [String],
                webLinks: [String]
            ) {
                self.videoLinks = videoLinks
                self.webLinks = webLinks
            }
        }

        public let title: String
        public let playerCount: String
        public let playTime: String
        public let summary: String
        public let initialSetup: [String]
        public let firstRoundGuide: [String]
        public let winCondition: String
        public let deepDive: [String]
        public let resources: GameResources
        public let confidence: Int
        public let notes: String

        public init(
            title: String,
            playerCount: String,
            playTime: String,
            summary: String,
            initialSetup: [String],
            firstRoundGuide: [String],
            winCondition: String,
            deepDive: [String],
            resources: GameResources,
            confidence: Int,
            notes: String
        ) {
            self.title = title
            self.playerCount = playerCount
            self.playTime = playTime
            self.summary = summary
            self.initialSetup = initialSetup
            self.firstRoundGuide = firstRoundGuide
            self.winCondition = winCondition
            self.deepDive = deepDive
            self.resources = resources
            self.confidence = confidence
            self.notes = notes
        }

    }
}

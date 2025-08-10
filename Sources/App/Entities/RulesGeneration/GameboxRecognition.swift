import Foundation
import Vapor

public enum GameboxRecognition {}

extension GameboxRecognition {
  public struct Request: Codable, Equatable, Sendable {
    public let image: Data

    public init(image: Data) {
      self.image = image
    }
  }

  public struct Response: Codable, Equatable, Sendable {
    public let guessedTitle: String
    public let confidence: Int
    public let alternativeTitles: [String]
    public let keywordsDetected: [String]
    public let notes: String

    public init(
      guessedTitle: String,
      confidence: Int,
      alternativeTitles: [String],
      keywordsDetected: [String],
      notes: String
    ) {
      self.guessedTitle = guessedTitle
      self.confidence = confidence
      self.alternativeTitles = alternativeTitles
      self.keywordsDetected = keywordsDetected
      self.notes = notes
    }
  }
}

import Fluent
import Foundation
import Vapor

protocol GameRequestStatsRepository: Repository {
    func incrementCount(for sanitizedTitle: String) async throws
    func topGames(limit: Int) async throws -> [GameRequestStats]
    func totalTrackedGames() async throws -> Int
    func find(bySanitizedTitle sanitizedTitle: String) async throws -> GameRequestStats?
}

struct DatabaseGameRequestStatsRepository: GameRequestStatsRepository, DatabaseRepository {
    typealias Model = GameRequestStats

    let database: Database

    func incrementCount(for sanitizedTitle: String) async throws {
        if let existing = try await GameRequestStats.query(on: database)
            .filter(\.$sanitizedGameTitle == sanitizedTitle)
            .first()
        {
            existing.requestCount += 1
            existing.lastRequestedAt = Date()
            try await existing.update(on: database)
        } else {
            let stats = GameRequestStats(
                sanitizedGameTitle: sanitizedTitle,
                requestCount: 1,
                lastRequestedAt: Date()
            )
            do {
                try await stats.create(on: database)
            } catch {
                // Handle race condition: another request may have created the record concurrently.
                // Retry as update if the unique constraint was violated.
                if let existing = try await GameRequestStats.query(on: database)
                    .filter(\.$sanitizedGameTitle == sanitizedTitle)
                    .first()
                {
                    existing.requestCount += 1
                    existing.lastRequestedAt = Date()
                    try await existing.update(on: database)
                } else {
                    throw error
                }
            }
        }
    }

    func topGames(limit: Int) async throws -> [GameRequestStats] {
        try await GameRequestStats.query(on: database)
            .sort(\.$requestCount, .descending)
            .limit(limit)
            .all()
    }

    func totalTrackedGames() async throws -> Int {
        try await GameRequestStats.query(on: database).count()
    }

    func find(bySanitizedTitle sanitizedTitle: String) async throws -> GameRequestStats? {
        try await GameRequestStats.query(on: database)
            .filter(\.$sanitizedGameTitle == sanitizedTitle)
            .first()
    }
}

extension Application.Repositories {
    var gameRequestStats: any GameRequestStatsRepository {
        application.gameRequestStatsRepository
    }
}

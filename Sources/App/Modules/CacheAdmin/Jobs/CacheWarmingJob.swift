import Foundation
import Vapor

/// Background job that pre-generates and caches rules summaries for popular games.
///
/// Runs on a periodic schedule, querying `GameRequestStats` to identify the most
/// requested games and ensuring their rules are cached in Redis. Uses a three-phase
/// strategy: skip if already cached, hydrate from DB if persisted, or generate via LLM.
final class CacheWarmingJob: @unchecked Sendable {

    private let app: Application
    private var task: Task<Void, Never>?
    private var isWarming = false

    /// Interval between periodic warming cycles (1 hour).
    static let jobInterval: UInt64 = 3600

    /// Maximum number of games to warm per cycle.
    static let maxGamesToWarm: Int = 50

    /// Delay between LLM generations in seconds (12 minutes = 5 req/hr rate limit).
    static let delayBetweenGenerations: UInt64 = 720

    init(app: Application) {
        self.app = app
    }

    /// Starts the periodic warming loop.
    func start() {
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Self.jobInterval))
                } catch {
                    break
                }
                await self.warmCaches()
            }
        }
    }

    /// Triggers an immediate warming cycle in the background.
    /// Skips if a warming cycle is already in progress.
    func triggerImmediate() {
        guard !isWarming else {
            app.logger.info("CacheWarmingJob: Warming cycle already in progress, skipping manual trigger")
            return
        }
        Task { [weak self] in
            guard let self else { return }
            await self.warmCaches()
        }
    }

    /// Gracefully shuts down the warming job.
    func shutdown() {
        task?.cancel()
        task = nil
    }

    // MARK: - Private

    private func warmCaches() async {
        guard !isWarming else { return }
        isWarming = true
        defer { isWarming = false }

        let logger = app.logger

        logger.info("CacheWarmingJob: Starting cache warming cycle")

        let repository = DatabaseGameRequestStatsRepository(database: app.db)
        let generatedRuleRepo = DatabaseGeneratedRuleRepository(database: app.db)

        let topGames: [GameRequestStats]
        do {
            topGames = try await repository.topGames(limit: Self.maxGamesToWarm)
        } catch {
            logger.error("CacheWarmingJob: Failed to fetch top games", metadata: [
                "error": .string(String(describing: error))
            ])
            return
        }

        guard !topGames.isEmpty else {
            logger.info("CacheWarmingJob: No games to warm")
            return
        }

        logger.info("CacheWarmingJob: Identified games for warming", metadata: [
            "count": .string("\(topGames.count)")
        ])

        var warmedCount = 0
        var skippedCount = 0
        var hydratedCount = 0
        var generatedCount = 0
        var errorCount = 0

        for stats in topGames {
            guard !Task.isCancelled else {
                logger.info("CacheWarmingJob: Cancelled, stopping warming cycle")
                break
            }

            let gameTitle = stats.sanitizedGameTitle
            let cacheKey = app.cacheKeyGeneratorService.generateRulesKey(for: gameTitle)

            // Phase 1: Check if already in Redis cache
            if let _ = await app.aiCacheService.get(key: cacheKey) {
                skippedCount += 1
                logger.debug("CacheWarmingJob: Already cached, skipping", metadata: [
                    "game_title": .string(gameTitle)
                ])
                continue
            }

            // Phase 2: Check if in database — hydrate Redis from DB (no LLM call)
            do {
                if let storedRule = try await generatedRuleRepo.find(bySanitizedTitle: gameTitle) {
                    let rulesSummary = makeRulesSummary(from: storedRule)
                    let encoded = try JSONEncoder().encode(rulesSummary)
                    if let encodedString = String(data: encoded, encoding: .utf8) {
                        let cacheConfig = try app.configuration.cache
                        await app.aiCacheService.set(
                            key: cacheKey,
                            value: encodedString,
                            ttl: cacheConfig.rulesGenerationTTL
                        )
                        hydratedCount += 1
                        logger.info("CacheWarmingJob: Hydrated cache from database", metadata: [
                            "game_title": .string(gameTitle)
                        ])

                        if let ruleId = storedRule.id {
                            try? await generatedRuleRepo.touch(ruleId)
                        }
                        continue
                    }
                }
            } catch {
                logger.warning("CacheWarmingJob: Database lookup failed, attempting LLM generation", metadata: [
                    "game_title": .string(gameTitle),
                    "error": .string(String(describing: error))
                ])
            }

            // Phase 3: Generate via LLM
            do {
                let combinedPrompt = """
                    \(PromptTemplates.RulesGeneration.systemPrompt)

                    \(PromptTemplates.RulesGeneration.userPrompt(gameTitle: gameTitle))
                    """

                let rulesResponse = try await app.llmService.generate(input: combinedPrompt)

                let validatedResponse = try app.aiResponseValidatorService.validateRulesSummaryResponse(
                    rulesResponse,
                    gameTitle: gameTitle,
                    clientIP: "cache-warming-job",
                    logger: logger
                )

                let rulesBuffer = ByteBuffer(string: validatedResponse)
                let rulesSummary = try JSONDecoder().decode(RulesSummary.Response.self, from: rulesBuffer)

                // Cache in Redis
                let cacheConfig = try app.configuration.cache
                await app.aiCacheService.set(
                    key: cacheKey,
                    value: validatedResponse,
                    ttl: cacheConfig.rulesGenerationTTL
                )

                // Persist to database
                await persistGeneratedSummary(
                    sanitizedTitle: gameTitle,
                    cacheKey: cacheKey,
                    rulesSummary: rulesSummary,
                    logger: logger,
                    repository: generatedRuleRepo
                )

                generatedCount += 1
                logger.info("CacheWarmingJob: Generated and cached via LLM", metadata: [
                    "game_title": .string(gameTitle)
                ])

                // Rate limit: sleep between LLM generations
                guard !Task.isCancelled else { break }
                do {
                    try await Task.sleep(for: .seconds(Self.delayBetweenGenerations))
                } catch {
                    break
                }
            } catch {
                errorCount += 1
                logger.error("CacheWarmingJob: LLM generation failed", metadata: [
                    "game_title": .string(gameTitle),
                    "error": .string(String(describing: error))
                ])
            }
        }

        warmedCount = hydratedCount + generatedCount
        logger.info("CacheWarmingJob: Warming cycle complete", metadata: [
            "warmed": .string("\(warmedCount)"),
            "skipped_cached": .string("\(skippedCount)"),
            "hydrated_from_db": .string("\(hydratedCount)"),
            "generated_via_llm": .string("\(generatedCount)"),
            "errors": .string("\(errorCount)")
        ])
    }

    private func makeRulesSummary(from model: GeneratedRuleModel) -> RulesSummary.Response {
        RulesSummary.Response(
            title: model.title,
            playerCount: model.playerCount,
            playTime: model.playTime,
            summary: model.summary,
            initialSetup: model.initialSetup,
            firstRoundGuide: model.firstRoundGuide,
            winCondition: model.winCondition,
            deepDive: model.deepDive,
            resources: .init(
                videoLinks: model.resourcesVideoLinks,
                webLinks: model.resourcesWebLinks
            ),
            confidence: model.confidence,
            notes: model.notes
        )
    }

    private func persistGeneratedSummary(
        sanitizedTitle: String,
        cacheKey: String,
        rulesSummary: RulesSummary.Response,
        logger: Logger,
        repository: any GeneratedRuleRepository
    ) async {
        let model = GeneratedRuleModel(
            originalTitle: sanitizedTitle,
            sanitizedTitle: sanitizedTitle,
            cacheKey: cacheKey,
            title: rulesSummary.title,
            playerCount: rulesSummary.playerCount,
            playTime: rulesSummary.playTime,
            summary: rulesSummary.summary,
            initialSetup: rulesSummary.initialSetup,
            firstRoundGuide: rulesSummary.firstRoundGuide,
            winCondition: rulesSummary.winCondition,
            deepDive: rulesSummary.deepDive,
            resourcesVideoLinks: rulesSummary.resources.videoLinks,
            resourcesWebLinks: rulesSummary.resources.webLinks,
            confidence: rulesSummary.confidence,
            notes: rulesSummary.notes,
            lastAccessedAt: Date()
        )

        do {
            try await repository.create(model)
        } catch {
            logger.warning("CacheWarmingJob: Create failed, attempting update", metadata: [
                "game_title": .string(sanitizedTitle),
                "error": .string(String(describing: error))
            ])

            do {
                if let existing = try await repository.find(bySanitizedTitle: sanitizedTitle) {
                    existing.cacheKey = cacheKey
                    existing.title = rulesSummary.title
                    existing.playerCount = rulesSummary.playerCount
                    existing.playTime = rulesSummary.playTime
                    existing.summary = rulesSummary.summary
                    existing.initialSetup = rulesSummary.initialSetup
                    existing.firstRoundGuide = rulesSummary.firstRoundGuide
                    existing.winCondition = rulesSummary.winCondition
                    existing.deepDive = rulesSummary.deepDive
                    existing.resourcesVideoLinks = rulesSummary.resources.videoLinks
                    existing.resourcesWebLinks = rulesSummary.resources.webLinks
                    existing.confidence = rulesSummary.confidence
                    existing.notes = rulesSummary.notes
                    existing.lastAccessedAt = Date()
                    try await repository.update(existing)
                }
            } catch {
                logger.error("CacheWarmingJob: Persist failed completely", metadata: [
                    "game_title": .string(sanitizedTitle),
                    "error": .string(String(describing: error))
                ])
            }
        }
    }
}

// MARK: - Lifecycle Handler

struct CacheWarmingJobLifecycleHandler: LifecycleHandler {
    let job: CacheWarmingJob

    func shutdown(_ app: Application) {
        job.shutdown()
    }
}

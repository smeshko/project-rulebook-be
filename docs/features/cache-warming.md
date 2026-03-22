# Cache Warming for Popular Games

**Date:** 2026-03-22
**Related Files:**
- `Sources/App/Modules/CacheAdmin/Jobs/CacheWarmingJob.swift`
- `Sources/App/Modules/CacheAdmin/Database/Models/GameRequestStats.swift`
- `Sources/App/Modules/CacheAdmin/Database/Repositories/GameRequestStatsRepository.swift`
- `Sources/App/Modules/CacheAdmin/Database/Migrations/CacheAdminMigrations.swift`
- `Sources/App/Modules/CacheAdmin/Controllers/CacheAdminController.swift`
- `Sources/App/Modules/CacheAdmin/CacheAdminRouter.swift`
- `Sources/App/Modules/RulesGeneration/Controller/RulesGenerationController.swift`
- `Sources/App/Entities/Cache/CacheResponseModels.swift`

## Overview

Cache warming pre-generates and caches rules summaries for the most popular games so that users experience instant (<100ms) responses instead of waiting for AI generation. The system tracks game request frequency via a `GameRequestStats` Fluent model, identifies the top 50 most-requested games, and warms the Redis cache using a three-phase strategy that respects LLM rate limits.

## What Was Built

- **GameRequestStats model** — Fluent model tracking per-game request frequency with unique `sanitizedGameTitle`, `requestCount`, and `lastRequestedAt`
- **CacheWarmingJob** — Background job running on a 1-hour cycle that warms caches for up to 50 popular games
- **Fire-and-forget stats tracking** — Every rules generation request increments game popularity stats without blocking the response
- **Admin warm endpoint** — `POST /api/v1/admin/cache/warm` to trigger immediate warming on demand
- **Race condition handling** — Repository uses create-then-update fallback for concurrent stat increments

## Technical Implementation

### Key Files

- `CacheWarmingJob.swift`: Background job with periodic and on-demand warming using three-phase strategy
- `GameRequestStats.swift`: Fluent model with schema `game_request_stats` for tracking request frequency
- `GameRequestStatsRepository.swift`: Database repository with `incrementCount`, `topGames`, and `find` methods
- `CacheAdminMigrations.swift`: Migration creating the `game_request_stats` table with unique constraint
- `CacheAdminController.swift`: Controller with `warmCache` method returning warming status
- `RulesGenerationController.swift`: Fire-and-forget stats increment on each rules request

### Key Patterns

- **Three-Phase Warming Strategy**: For each popular game, the job first checks if rules are already cached in Redis (skip), then checks if rules exist in the database (hydrate to cache), and finally generates via LLM as a last resort (generate). This minimizes expensive LLM calls.

- **Overlap Prevention**: The `CacheWarmingJob` uses an `isWarming` flag to prevent concurrent warming cycles. Both periodic and manual triggers check this flag before starting.

- **Fire-and-Forget Stats Tracking**: `RulesGenerationController` wraps the `incrementCount` call in a detached `Task` so it never blocks the user response. Failures are logged at warning level but don't affect the request.

- **Race Condition Handling in incrementCount**: The repository first attempts to create a new `GameRequestStats` record. If a unique constraint violation occurs (concurrent insert), it falls back to finding and updating the existing record.

- **LifecycleHandler Background Job**: `CacheWarmingJob` follows the same pattern as `PendingValidationJob` — a `final class` with `start()`/`shutdown()` lifecycle methods registered via a `LifecycleHandler` struct.

### Code Examples

Triggering cache warming programmatically:

```swift
// On-demand warming via the job instance
app.cacheWarmingJob?.triggerImmediate()
```

Incrementing game stats (fire-and-forget pattern):

```swift
Task {
    if let repo = req.application.serviceStorage[GameRequestStatsRepositoryKey.self] {
        try? await repo.incrementCount(for: sanitizedGameTitle)
    }
}
```

## How to Use

1. **Automatic warming**: The job runs automatically every hour after application startup via `LifecycleHandler` registration in `Application-Setup.swift`
2. **Manual warming**: Send `POST /api/v1/admin/cache/warm` with admin authentication to trigger immediate warming
3. **Monitor popularity**: Query `GameRequestStats` via the repository to see which games are most requested
4. **Adjust parameters**: Modify constants in `CacheWarmingJob` — `jobInterval` (cycle frequency), `maxGamesToWarm` (top N games), `delayBetweenGenerations` (LLM rate limit spacing)

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `jobInterval` | `UInt64` | `3600` | Seconds between warming cycles |
| `maxGamesToWarm` | `Int` | `50` | Maximum number of games to warm per cycle |
| `delayBetweenGenerations` | `UInt64` | `720` | Seconds between LLM generation calls (12 min = 5 req/hr) |

These are compile-time constants in `CacheWarmingJob.swift`. The delay of 720 seconds between LLM calls ensures the warming process stays within the production rate limit of 5 requests per hour.

## Notes

- The warming job only generates rules for games that don't already have cached or persisted results, making re-runs efficient
- The `isWarming` flag prevents overlapping cycles — if a warming cycle is already in progress, `triggerImmediate()` is a no-op
- Stats tracking uses optional access (`serviceStorage[Key.self]`) to safely handle test environments where the repository may not be registered
- The admin endpoint returns immediately with a "started" status; warming runs asynchronously in the background
- Warming metrics (warmed, skipped, hydrated, generated, errors) are logged at the end of each cycle for monitoring

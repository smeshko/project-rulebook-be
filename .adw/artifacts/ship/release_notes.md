## [Unreleased] - 2026-03-22

### Added
- Add POST /api/v1/admin/cache/warm endpoint
- Increment game request stats on rules generation
- Add GameRequestStats model, migration, repository, and CacheWarmingJob

### Fixed
- Cycle 2 - prevent overlapping warming cycles, fix req capture in Task
- Resolve race condition in incrementCount and optimize warmCache query

### Documentation
- Add feature documentation for cache warming (RULE-166)

### Other
- Add tests for GameRequestStats and cache warming endpoint

## [Unreleased] - 2026-03-19

### Added
- Structured JSON logging for production/staging environments with promoted `correlation_id` field

### Changed
- Propagate request-scoped logger into LLM services (GoogleGeminiService, OpenAIService)
- Propagate request-scoped logger into cache services (RedisCacheService, RedisAICacheService)
- Audit and optimize CorrelationIDMiddleware and ErrorMiddleware for consistent correlation ID handling

### Fixed
- Fix missed `app.logger` usages and optimize date formatter in StructuredLogHandler
- Address code review findings for correlation ID propagation

### Documentation
- Add feature documentation for structured logging with correlation IDs

### Other
- Add correlation ID integration tests (generation, header propagation, priority order, error responses)
- Replace manual `UUID().uuidString` request IDs with `req.correlationID` in RulesGenerationController

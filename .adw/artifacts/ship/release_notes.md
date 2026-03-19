## [Unreleased] - 2026-03-19

### Added
- Register POST route in feedback router with OpenAPI documentation
- Implement feedback submission controller with input validation and trimming
- Create FeedbackError enum with abort error mapping for structured validation errors
- Add feedback rate limit type and configuration (5 req/hour production, 50 req/hour development)

### Fixed
- Trim userContact and normalize empty values to nil
- Add gameTitle max length validation (500 chars)

### Documentation
- Update feedback module docs with submission endpoint details

### Other
- Add 10 comprehensive feedback submission integration tests

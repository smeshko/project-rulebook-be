## [Unreleased] - 2026-04-24

### Added
- Add `AI_CONFIDENCE_THRESHOLD` to services config
- Add confidence extraction helper to AI validator
- Add `LLMFallbackService` orchestrator with structured logs
- Wire LLM fallback orchestrator into service setup

### Fixed
- Resolve adversarial review findings (cycle 1)
- Include `secondary_error` in both-failed log (cycle 2)

### Documentation
- Document LLM low-confidence fallback feature
- Register `llm-confidence-fallback` in conditional docs guide

### Other
- Add integration tests for LLM fallback wiring

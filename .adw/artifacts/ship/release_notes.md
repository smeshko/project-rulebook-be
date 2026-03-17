## [Unreleased] - 2026-03-17

### Added
- Add receipt case to RateLimitType and RateLimitConfiguration
- Add receipt path detection and JSON 429 response body
- Compute accurate Retry-After from oldest request timestamp
- Add receipt-hash-based rate limiting in controller
- Update MockRateLimitService for receipt type

### Fixed
- Cycle 1: Fix dictionary mutation, waitlist config, hash cleanup
- Cycle 2: Move hash rate check before external validation

### Other
- Add receipt rate limiting tests

### Documentation
- Add receipt rate limiting feature documentation

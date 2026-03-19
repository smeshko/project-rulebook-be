## [Unreleased] - 2026-03-19

### Added
- Add health module following ModuleInterface pattern
- Add health router at root /health path
- Add health controller with database and redis probes
- Add health check response DTO
- Register health module and remove old basic route

### Fixed
- Improve health check robustness

### Documentation
- Add feature documentation for health check endpoint

### Other
- Add health check endpoint integration tests

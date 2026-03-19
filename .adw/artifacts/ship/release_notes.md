## [Unreleased] - 2026-03-19

### Added
- Add pubsub verification token to Google Play config
- Create Google notification service for Pub/Sub RTDN decoding and voided purchase verification
- Create Google notifications controller with token verification and notification routing
- Register Google notification service and route (`POST /api/v1/notifications/google`)

### Fixed
- Add 401 cache invalidation, remove unused isVoided property
- Remove extra blank line from enum cleanup

### Documentation
- Add feature documentation for Google Play RTDN notifications

### Other
- Add Google notifications controller tests (11 test cases)

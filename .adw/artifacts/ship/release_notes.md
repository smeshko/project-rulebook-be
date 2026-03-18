## [Unreleased] - 2026-03-18

### Added
- Register Apple notification webhook route
- Create AppleNotificationsController
- Create AppleNotificationService for JWS verification
- Add markRefunded and markRevoked repository methods
- Create database migration v3 for transaction status
- Add TransactionStatus enum and new fields to TransactionModel

### Fixed
- Handle unknown Apple notification types gracefully
- Fix @Enum/string mismatch and silent missing-transaction handling

### Other
- Add AppleNotificationsController integration tests

### Documentation
- Add Apple Server Notifications V2 feature documentation

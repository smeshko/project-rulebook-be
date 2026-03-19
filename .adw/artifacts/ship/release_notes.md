## [Unreleased] - 2026-03-19

### Added
- Extend TransactionModel with pending validation fields and v4 migration
- Add pending validation repository queries (`findPendingValidations`, `findPendingByReceiptHash`, `updateStatus`)
- Handle store API downtime with 202 pending response for transient upstream errors
- Create PendingValidationJob for background retry with exponential backoff (5min, 20min, 60min)
- Register PendingValidationJob in application setup with LifecycleHandler

### Fixed
- Fix job retention, retry logic, and data cleanup (review cycle 1)
- Receipt dedup, job lifecycle, and data cleanup (review cycle 2)

### Testing
- Add graceful degradation tests and fix v4 migration for SQLite compatibility
- 10 integration/unit tests covering timeout-to-202, pending storage, dedup, definitive errors-to-403, repository queries, backoff validation

### Documentation
- Add feature doc for store API graceful degradation

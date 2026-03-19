# Structured Logging with Correlation IDs

**Date:** 2026-03-19
**Related Files:** `Sources/App/Common/Logging/StructuredLogHandler.swift`, `Sources/App/Common/Middleware/CorrelationIDMiddleware.swift`, `Sources/App/Common/Middleware/ErrorMiddleware.swift`

## Overview

Implements structured JSON logging for production/staging environments and ensures correlation IDs propagate consistently through all service layers (LLM, cache, controllers). Every log entry in production is a single-line JSON object with a promoted `correlation_id` field for easy filtering in log aggregation systems.

## What Was Built

- **StructuredLogHandler**: A Swift-Log `LogHandler` that outputs JSON-formatted log lines to stderr in production/staging
- **Request-scoped logger propagation**: LLM services (`GoogleGeminiService`, `OpenAIService`) and cache services (`RedisCacheService`) accept `request.logger` via `for(_:)` / `withLogger(_:)` methods
- **Controller cleanup**: Replaced manual `UUID().uuidString` request IDs with `req.correlationID` in `RulesGenerationController`
- **Middleware audit**: Verified `CorrelationIDMiddleware` and `ErrorMiddleware` correctly propagate correlation IDs through headers, logger metadata, and error responses
- **Integration tests**: Comprehensive tests for correlation ID generation, propagation, header priority, and error response inclusion

## Technical Implementation

### Key Files

- `Sources/App/Common/Logging/StructuredLogHandler.swift`: JSON log handler with correlation_id promotion
- `Sources/App/Common/Middleware/CorrelationIDMiddleware.swift`: Extracts/generates correlation IDs, stores in request storage and logger metadata
- `Sources/App/Entrypoint/entrypoint.swift`: Environment-gated log handler bootstrap
- `Sources/App/Services/LLM/GoogleGeminiService.swift`: Accepts request-scoped logger via `for(_:)`
- `Sources/App/Services/LLM/OpenAIService.swift`: Accepts request-scoped logger via `for(_:)`
- `Sources/App/Services/Cache/RedisCacheService.swift`: Accepts request-scoped logger via `withLogger(_:)`

### Key Patterns

- **Request-scoped logger propagation**: Services store a `Logger` property. The `for(_ request:)` factory method creates a request-scoped service instance that uses `request.logger` (which already carries `correlation_id` metadata from the middleware). This ensures all downstream log calls automatically include the correlation ID without manual metadata passing.

- **Environment-gated log handler**: In `entrypoint.swift`, `LoggingSystem.bootstrap` selects `StructuredLogHandler` for production/staging and Vapor's default `StreamLogHandler` for development. This is configured once at startup.

- **Correlation ID promotion**: The `StructuredLogHandler` extracts `correlation_id` from the merged metadata dictionary and writes it as a top-level JSON key, making it directly filterable without nested JSON queries.

### Code Examples

```swift
// Propagating request logger to an LLM service
let geminiService = req.services.geminiService.for(req)
// All logs from geminiService now include the request's correlation_id

// Propagating request logger to cache service
let cacheService = req.services.cacheService.withLogger(req.logger)
// Cache operation logs now carry correlation context

// Accessing correlation ID directly
let correlationID = req.correlationID
```

### JSON Log Output Format

```json
{"correlation_id":"abc-123","label":"app","level":"info","message":"Request started","metadata":{"method":"GET","path":"/health"},"timestamp":"2026-03-19T12:00:00.000Z"}
```

## How to Use

1. **For new services**: Add a `logger: Logger` property and a `for(_ request: Request)` factory method that passes `request.logger` to the new instance
2. **For controllers**: Always use `req.logger` for logging — never create manual request IDs
3. **For correlation ID access**: Use `req.correlationID` to get the current request's correlation ID
4. **For log filtering**: In production, filter logs by `correlation_id` JSON field to trace a complete request lifecycle

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| Environment | `APP_ENV` | development | Controls log format: `production`/`staging` = JSON, `development` = text |
| Incoming headers | Hardcoded | — | Checks `X-Correlation-ID`, `X-Request-ID`, `X-Trace-ID`, `X-B3-TraceId` in priority order |
| Outgoing header | Hardcoded | — | Always returns `X-Correlation-ID` in response |

## Notes

- The `ISO8601DateFormatter` is cached as a static property with `nonisolated(unsafe)` to avoid repeated allocation — `ISO8601DateFormatter` is thread-safe
- Correlation ID is included in both success and error response headers via the middleware
- The `ErrorMiddleware` independently adds `correlation_id` to error log metadata, providing redundancy if the correlation middleware's catch block doesn't fire
- Header priority order: `X-Correlation-ID` > `X-Request-ID` > `X-Trace-ID` > `X-B3-TraceId`

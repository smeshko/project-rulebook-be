# LLM Low-Confidence Fallback to Secondary Model

**Date:** 2026-04-24
**Related Files:**
- `Sources/App/Services/LLM/LLMFallbackService.swift`
- `Sources/App/Services/LLM/LLMService.swift`
- `Sources/App/Services/Validation/AIResponseValidationService.swift`
- `Sources/App/Services/Configuration/ConfigurationTypes.swift`
- `Sources/App/Common/Extensions/Application+Services.swift`
- `Sources/App/Entrypoint/Application-Setup.swift`
- `Tests/AppTests/Services/LLM/LLMFallbackServiceTests.swift`
- `Tests/AppTests/Tests/ControllerTests/RulesGenerationTests/RulesGenerationFallbackTests.swift`

## Overview

Rules generation and game-box recognition now use a two-model pipeline. When the primary LLM (OpenAI) returns a response with `confidence < AI_CONFIDENCE_THRESHOLD` (default 70), the request is automatically retried against the secondary LLM (Gemini) and the higher-confidence result is returned to the client. This improves answer quality for ambiguous games without inflating latency on the happy path — when the primary is confident (>= threshold), the secondary is never invoked.

## What Was Built

- **`LLMFallbackService`** — `LLMService`-conforming orchestrator wrapping a primary and secondary model. Decides per-request whether to fall back based on parsed confidence and wins-ties-to-primary semantics.
- **Confidence extraction helper** — `AIResponseValidationService.confidenceFrom(validatedJSONString:)` returns `Int?` without throwing. Missing or malformed values are treated as `confidence = 0` by the orchestrator.
- **`AI_CONFIDENCE_THRESHOLD`** env var wired into `ServicesConfig` with clamping to `0...100`; invalid values fall back to the default of 70 rather than crashing.
- **Transparent wiring** — `app.llmService` and `req.services.llm` now resolve to the fallback wrapper. No controller or background-job changes were needed.
- **Structured log line** — Every fallback invocation emits one log entry with `event=llm_fallback`, `primary_model`, `primary_confidence`, `secondary_model`, `secondary_confidence`, `selected_model`, `reason`, and `threshold`. The request logger is used so the correlation ID is preserved for aggregation.

## Technical Implementation

### Decision Matrix

| Primary outcome                | Secondary outcome              | Result                  | Reason metadata                |
| ------------------------------ | ------------------------------ | ----------------------- | ------------------------------ |
| `confidence >= threshold`      | not invoked                    | primary response        | `llm_primary_accepted` (debug) |
| `confidence < threshold`       | `confidence > primary`         | secondary response      | `secondary_higher_confidence`  |
| `confidence < threshold`       | `confidence <= primary`        | primary response        | `both_low_confidence`          |
| `confidence < threshold`       | throws                         | primary response (warn) | `secondary_failed`             |
| throws                         | success                        | secondary response      | `primary_failed`                |
| throws                         | throws                         | primary error rethrown  | n/a (logged as error)          |

Primary wins ties. Malformed or missing `confidence` is treated as `0` so the fallback still fires.

### Key Patterns

- **Transparent wrap** — The orchestrator conforms to `LLMService` and is assigned to `app.llmService` at startup. All existing callers (`RulesGenerationController`, `CacheWarmingJob`) route through it without code changes.
- **Request-scoped cloning** — `LLMFallbackService.for(_:)` clones both inner services via their own `for(_:)` methods and adopts the request's logger, so `correlation_id` flows into the fallback log entry.
- **No duplicated retry** — Each underlying service already handles transient errors (rate-limit backoff, 5xx retry). The fallback sits above, so we don't multiply retry latency.

### Error Handling

- Primary succeeds with bad JSON or missing confidence → confidence = 0, secondary invoked.
- Primary throws, secondary succeeds → secondary returned, fallback log entry with `reason=primary_failed`.
- Primary succeeds low, secondary throws → primary returned with a `warning` log, no error propagated.
- Both throw → primary error is re-thrown; an `error` log entry records both failures for diagnosis.

## Configuration

- `AI_CONFIDENCE_THRESHOLD` — Integer in `0...100`. Default `70`. Invalid/out-of-range values silently fall back to the default.

## Tests

- **Unit**: `LLMFallbackServiceTests` covers the full decision matrix for both `generate` and `analyzeImage`, plus edge cases (missing confidence, malformed JSON, exact-threshold acceptance, error paths).
- **Integration**: `RulesGenerationFallbackTests` verifies end-to-end wiring through `app.llmService.for(request)` with the real `DefaultAIResponseValidationService` and a live `Application` instance.
- **Validator**: New test cases in `AIResponseValidationServiceTests` for `confidenceFrom(validatedJSONString:)`.
- **Config**: New test cases in `ConfigurationTests` for default/custom/invalid/boundary/out-of-range threshold values.

## Operational Notes

- The response body shape is unchanged. Clients continue to see a single JSON payload with a `confidence` integer; the fallback decision is transparent.
- To grep all fallback events in production logs, filter on `event=llm_fallback`. To count fallback invocations per cause: group by `reason`.
- The fallback path costs one extra LLM call per triggered request. Monitor `event=llm_fallback` rate vs. the overall request rate to size capacity.

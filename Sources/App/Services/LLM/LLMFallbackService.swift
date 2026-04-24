import Foundation
import Logging
import Vapor

/// Orchestrator that wraps a primary and secondary `LLMService` and retries
/// against the secondary when the primary returns a low-confidence response.
///
/// ## Decision Rules
/// - Primary succeeds with `confidence >= threshold` → return primary (secondary not called).
/// - Primary succeeds with `confidence < threshold` → call secondary, return the higher-confidence response (primary wins ties).
/// - Primary throws → call secondary, return its result (or re-throw primary error if secondary also fails).
/// - Primary returns malformed/empty JSON → treated as `confidence = 0` (fallback triggers).
/// - Primary succeeds low, secondary throws → return primary with a warning log.
///
/// ## Logging
/// On the happy path (primary accepted), emits a single `debug` log.
/// When fallback triggers, emits one `info` (or `warning` on secondary error) log
/// carrying `correlation_id`, model names, both confidence scores, selected model,
/// and a `reason` tag for aggregation.
///
/// Immutable after construction; inner services are `Sendable`.
final class LLMFallbackService: LLMService, @unchecked Sendable {
    private let primary: LLMService
    private let secondary: LLMService
    private let threshold: Int
    private let validator: AIResponseValidationService
    private let logger: Logger
    private let primaryName: String
    private let secondaryName: String

    init(
        primary: LLMService,
        secondary: LLMService,
        threshold: Int,
        validator: AIResponseValidationService,
        logger: Logger,
        primaryName: String,
        secondaryName: String
    ) {
        self.primary = primary
        self.secondary = secondary
        self.threshold = threshold
        self.validator = validator
        self.logger = logger
        self.primaryName = primaryName
        self.secondaryName = secondaryName
    }

    // MARK: - LLMService

    func generate(input: String) async throws -> String {
        try await orchestrate(
            primaryCall: { try await self.primary.generate(input: input) },
            secondaryCall: { try await self.secondary.generate(input: input) }
        )
    }

    func analyzeImage(imageData: String, prompt: String) async throws -> String {
        try await orchestrate(
            primaryCall: { try await self.primary.analyzeImage(imageData: imageData, prompt: prompt) },
            secondaryCall: { try await self.secondary.analyzeImage(imageData: imageData, prompt: prompt) }
        )
    }

    func `for`(_ request: Request) -> LLMService {
        LLMFallbackService(
            primary: primary.for(request),
            secondary: secondary.for(request),
            threshold: threshold,
            validator: validator,
            logger: request.logger,
            primaryName: primaryName,
            secondaryName: secondaryName
        )
    }

    // MARK: - Private

    private func orchestrate(
        primaryCall: () async throws -> String,
        secondaryCall: () async throws -> String
    ) async throws -> String {
        // Phase 1: call primary (may throw)
        let primaryResult: Result<(response: String, confidence: Int), Error>
        do {
            let response = try await primaryCall()
            let confidence = extractConfidence(from: response)
            primaryResult = .success((response, confidence))
        } catch {
            primaryResult = .failure(error)
        }

        // Happy path — primary accepted
        if case .success(let primary) = primaryResult, primary.confidence >= threshold {
            logger.debug("llm_primary_accepted", metadata: [
                "event": .string("llm_primary_accepted"),
                "primary_model": .string(primaryName),
                "primary_confidence": .string("\(primary.confidence)"),
                "threshold": .string("\(threshold)")
            ])
            return primary.response
        }

        // Phase 2: call secondary (may throw)
        let secondaryResult: Result<(response: String, confidence: Int), Error>
        do {
            let response = try await secondaryCall()
            let confidence = extractConfidence(from: response)
            secondaryResult = .success((response, confidence))
        } catch {
            secondaryResult = .failure(error)
        }

        // Decision matrix
        switch (primaryResult, secondaryResult) {
        case (.success(let primary), .success(let secondary)):
            // Primary wins ties (>=), secondary must be strictly higher.
            let selectPrimary = primary.confidence >= secondary.confidence
            let reason = determineReason(secondaryConfidence: secondary.confidence)
            logFallback(
                level: .info,
                primaryConfidence: primary.confidence,
                secondaryConfidence: secondary.confidence,
                selectedPrimary: selectPrimary,
                reason: reason
            )
            return selectPrimary ? primary.response : secondary.response

        case (.success(let primary), .failure(let secondaryError)):
            logFallback(
                level: .warning,
                primaryConfidence: primary.confidence,
                secondaryConfidence: nil,
                selectedPrimary: true,
                reason: "secondary_failed",
                secondaryError: secondaryError
            )
            return primary.response

        case (.failure(let primaryError), .success(let secondary)):
            logFallback(
                level: .info,
                primaryConfidence: nil,
                secondaryConfidence: secondary.confidence,
                selectedPrimary: false,
                reason: "primary_failed",
                primaryError: primaryError
            )
            return secondary.response

        case (.failure(let primaryError), .failure):
            // Both failed — re-throw the primary error (the originating cause).
            logger.error("llm_fallback_both_failed", metadata: [
                "event": .string("llm_fallback_both_failed"),
                "primary_model": .string(primaryName),
                "secondary_model": .string(secondaryName),
                "primary_error": .string(String(describing: primaryError))
            ])
            throw primaryError
        }
    }

    private func extractConfidence(from response: String) -> Int {
        validator.confidenceFrom(validatedJSONString: response) ?? 0
    }

    private func determineReason(secondaryConfidence: Int) -> String {
        // Entry precondition: primary confidence < threshold (Phase 1 returned otherwise).
        // If secondary is also below threshold, both are low-confidence. Otherwise
        // secondary cleared the bar and, since primary < threshold <= secondary,
        // the secondary must have been selected (strictly higher).
        secondaryConfidence < threshold ? "both_low_confidence" : "secondary_higher_confidence"
    }

    private func logFallback(
        level: Logger.Level,
        primaryConfidence: Int?,
        secondaryConfidence: Int?,
        selectedPrimary: Bool,
        reason: String,
        primaryError: Error? = nil,
        secondaryError: Error? = nil
    ) {
        var metadata: Logger.Metadata = [
            "event": .string("llm_fallback"),
            "primary_model": .string(primaryName),
            "secondary_model": .string(secondaryName),
            "selected_model": .string(selectedPrimary ? "primary" : "secondary"),
            "reason": .string(reason),
            "threshold": .string("\(threshold)")
        ]
        if let primaryConfidence {
            metadata["primary_confidence"] = .string("\(primaryConfidence)")
        }
        if let secondaryConfidence {
            metadata["secondary_confidence"] = .string("\(secondaryConfidence)")
        }
        if let primaryError {
            metadata["primary_error"] = .string(String(describing: primaryError))
        }
        if let secondaryError {
            metadata["secondary_error"] = .string(String(describing: secondaryError))
        }
        logger.log(level: level, "llm_fallback", metadata: metadata)
    }
}

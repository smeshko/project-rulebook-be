@testable import App
import Foundation
import Testing
import Vapor
import VaporTesting

/// Integration tests verifying that the `LLMFallbackService` is correctly wired
/// into the application service container and that cross-cutting concerns
/// (confidence extraction via the real validator, structured logging, and the
/// request-scoped `for(_:)` cloning used by `req.services.llm`) all work
/// together as expected on a live `Application`.
///
/// These tests exercise the full service wiring minus HTTP routing — a higher-
/// fidelity HTTP-level integration test exists in principle but hits a
/// pre-existing Vapor `ServeCommand` shutdown assertion unrelated to this
/// story. The controller integration is verified by Task 6 (no code change
/// needed; the fallback wrap is transparent).
@Suite(.serialized)
struct RulesGenerationFallbackTests {

    private static func validRulesJSON(title: String, confidence: Int) -> String {
        """
        {
            "title": "\(title)",
            "summary": "A safe summary for \(title) with enough content to pass length checks.",
            "playerCount": "2-4",
            "playTime": "60 minutes",
            "initialSetup": ["Setup step one", "Setup step two"],
            "firstRoundGuide": ["Draw cards", "Take actions"],
            "winCondition": "Score the most points",
            "deepDive": ["Strategy tip one", "Strategy tip two"],
            "resources": {"videoLinks": [], "webLinks": []},
            "confidence": \(confidence),
            "notes": "integration"
        }
        """
    }

    @Test("req.services.llm routes through LLMFallbackService — secondary used when primary is low confidence", .tags(.p0Critical, .aiServices, .integration))
    func requestServices_routesThroughFallback() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app
        let originalLLM = app.llmService
        defer { app.llmService = originalLLM }

        let primary = RecordingLLMService()
        let secondary = RecordingLLMService()
        primary.generateResult = .success(Self.validRulesJSON(title: "PrimaryWins", confidence: 40))
        secondary.generateResult = .success(Self.validRulesJSON(title: "SecondaryWins", confidence: 95))

        app.llmService = LLMFallbackService(
            primary: primary,
            secondary: secondary,
            threshold: 70,
            validator: DefaultAIResponseValidationService(),
            logger: app.logger,
            primaryName: "TestPrimary",
            secondaryName: "TestSecondary"
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let result = try await app.llmService.for(request).generate(input: "prompt")

        let decoded = try JSONDecoder().decode(RulesSummary.Response.self, from: Data(result.utf8))
        #expect(decoded.title == "SecondaryWins")
        #expect(decoded.confidence == 95)

        #expect(primary.generateCallCount == 1)
        #expect(secondary.generateCallCount == 1)
    }

    @Test("req.services.llm returns primary when primary confidence is above threshold", .tags(.p0Critical, .aiServices, .integration))
    func requestServices_primaryAccepted_secondarySkipped() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app
        let originalLLM = app.llmService
        defer { app.llmService = originalLLM }

        let primary = RecordingLLMService()
        let secondary = RecordingLLMService()
        primary.generateResult = .success(Self.validRulesJSON(title: "PrimaryWins", confidence: 92))
        secondary.generateResult = .success(Self.validRulesJSON(title: "SecondaryWins", confidence: 99))

        app.llmService = LLMFallbackService(
            primary: primary,
            secondary: secondary,
            threshold: 70,
            validator: DefaultAIResponseValidationService(),
            logger: app.logger,
            primaryName: "TestPrimary",
            secondaryName: "TestSecondary"
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let result = try await app.llmService.for(request).generate(input: "prompt")

        let decoded = try JSONDecoder().decode(RulesSummary.Response.self, from: Data(result.utf8))
        #expect(decoded.title == "PrimaryWins")
        #expect(decoded.confidence == 92)

        #expect(primary.generateCallCount == 1)
        #expect(secondary.generateCallCount == 0)
    }

    @Test("fallback survives primary error — secondary result returned", .tags(.p1Core, .aiServices, .integration))
    func requestServices_primaryThrows_fallsThroughToSecondary() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app
        let originalLLM = app.llmService
        defer { app.llmService = originalLLM }

        let primary = RecordingLLMService()
        let secondary = RecordingLLMService()
        primary.generateResult = .failure(IntegrationFallbackError.boom)
        secondary.generateResult = .success(Self.validRulesJSON(title: "SecondaryWins", confidence: 80))

        app.llmService = LLMFallbackService(
            primary: primary,
            secondary: secondary,
            threshold: 70,
            validator: DefaultAIResponseValidationService(),
            logger: app.logger,
            primaryName: "TestPrimary",
            secondaryName: "TestSecondary"
        )

        let request = Request(application: app, on: app.eventLoopGroup.next())
        let result = try await app.llmService.for(request).generate(input: "prompt")

        let decoded = try JSONDecoder().decode(RulesSummary.Response.self, from: Data(result.utf8))
        #expect(decoded.title == "SecondaryWins")
    }
}

// MARK: - Test-local helpers

private enum IntegrationFallbackError: Error, Equatable {
    case boom
}

private final class RecordingLLMService: LLMService, @unchecked Sendable {
    var generateResult: Result<String, Error> = .success("")
    var analyzeImageResult: Result<String, Error> = .success("")

    private(set) var generateCallCount: Int = 0
    private(set) var analyzeImageCallCount: Int = 0

    func generate(input: String) async throws -> String {
        generateCallCount += 1
        switch generateResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func analyzeImage(imageData: String, prompt: String) async throws -> String {
        analyzeImageCallCount += 1
        switch analyzeImageResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func `for`(_ request: Request) -> LLMService {
        self
    }
}

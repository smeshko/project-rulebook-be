@testable import App
import Foundation
import Logging
import Testing
import Vapor

/// Unit tests for `LLMFallbackService` — the orchestrator that retries low-confidence
/// primary LLM responses against a secondary model and returns the higher-confidence result.
@Suite(.serialized)
struct LLMFallbackServiceTests {

    // MARK: - Helpers

    private static let threshold = 70
    private static let primaryName = "PrimaryLLM"
    private static let secondaryName = "SecondaryLLM"

    private static func makeService(
        primary: MockLLMService,
        secondary: MockLLMService,
        threshold: Int = threshold
    ) -> LLMFallbackService {
        LLMFallbackService(
            primary: primary,
            secondary: secondary,
            threshold: threshold,
            validator: DefaultAIResponseValidationService(),
            logger: Logger(label: "test.fallback"),
            primaryName: primaryName,
            secondaryName: secondaryName
        )
    }

    private static func responseJSON(confidence: Int, marker: String = "P") -> String {
        "{\"title\":\"Chess\",\"confidence\":\(confidence),\"source\":\"\(marker)\"}"
    }

    // MARK: - generate(input:)

    @Test("primary above threshold returns primary and skips secondary", .tags(.p0Critical, .aiServices, .unit))
    func primaryHighConfidence_skipsSecondary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 85, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 95, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"P\""))
        #expect(primary.generateCallCount == 1)
        #expect(secondary.generateCallCount == 0)
    }

    @Test("primary below threshold, secondary higher — secondary returned", .tags(.p0Critical, .aiServices, .unit))
    func primaryLow_secondaryHigher_returnsSecondary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 40, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 80, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"S\""))
        #expect(primary.generateCallCount == 1)
        #expect(secondary.generateCallCount == 1)
    }

    @Test("primary below threshold, secondary lower — primary returned (tie-break to primary when strictly lower)", .tags(.p1Core, .aiServices, .unit))
    func primaryLow_secondaryLower_returnsPrimary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 60, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 30, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"P\""))
    }

    @Test("primary below threshold, secondary equal — primary returned (tie-break to primary)", .tags(.p1Core, .aiServices, .unit))
    func primaryLow_secondaryEqual_returnsPrimary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 50, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 50, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"P\""))
    }

    @Test("both below threshold — higher wins, tie favors primary", .tags(.p1Core, .aiServices, .unit))
    func bothBelowThreshold_higherWins() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 25, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 35, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"S\""))
        #expect(secondary.generateCallCount == 1)
    }

    @Test("primary throws, secondary succeeds — secondary returned", .tags(.p0Critical, .aiServices, .unit))
    func primaryThrows_secondaryReturns() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .failure(MockLLMError.generic)
        secondary.generateResult = .success(Self.responseJSON(confidence: 90, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"S\""))
        #expect(secondary.generateCallCount == 1)
    }

    @Test("primary succeeds low, secondary throws — primary returned (no propagation)", .tags(.p0Critical, .aiServices, .unit))
    func primaryLow_secondaryThrows_returnsPrimary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 40, marker: "P"))
        secondary.generateResult = .failure(MockLLMError.generic)

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"P\""))
    }

    @Test("both throw — re-throws primary error", .tags(.p0Critical, .aiServices, .unit))
    func bothThrow_rethrowsPrimary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .failure(MockLLMError.primaryOnly)
        secondary.generateResult = .failure(MockLLMError.secondaryOnly)

        let service = Self.makeService(primary: primary, secondary: secondary)

        await #expect(throws: MockLLMError.primaryOnly) {
            _ = try await service.generate(input: "hello")
        }
    }

    @Test("missing confidence field — treated as 0, triggers fallback", .tags(.p1Core, .aiServices, .unit))
    func missingConfidence_triggersFallback() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success("{\"title\":\"Chess\",\"source\":\"P\"}")
        secondary.generateResult = .success(Self.responseJSON(confidence: 90, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"S\""))
        #expect(secondary.generateCallCount == 1)
    }

    @Test("malformed JSON from primary — treated as 0, triggers fallback", .tags(.p1Core, .aiServices, .unit))
    func malformedPrimary_triggersFallback() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success("not json at all")
        secondary.generateResult = .success(Self.responseJSON(confidence: 90, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"S\""))
    }

    @Test("primary confidence exactly equals threshold — accepted without fallback", .tags(.p1Core, .aiServices, .unit))
    func primaryExactlyAtThreshold_accepted() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 70, marker: "P"))
        secondary.generateResult = .success(Self.responseJSON(confidence: 99, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.generate(input: "hello")

        #expect(result.contains("\"source\":\"P\""))
        #expect(secondary.generateCallCount == 0)
    }

    // MARK: - analyzeImage(imageData:prompt:)

    @Test("analyzeImage: primary high confidence skips secondary", .tags(.p0Critical, .aiServices, .unit))
    func analyzeImage_primaryHigh_skipsSecondary() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.analyzeImageResult = .success(Self.responseJSON(confidence: 90, marker: "P"))
        secondary.analyzeImageResult = .success(Self.responseJSON(confidence: 99, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.analyzeImage(imageData: "data:image/png;base64,AAA", prompt: "what is this")

        #expect(result.contains("\"source\":\"P\""))
        #expect(secondary.analyzeImageCallCount == 0)
    }

    @Test("analyzeImage: primary low, secondary higher returns secondary", .tags(.p0Critical, .aiServices, .unit))
    func analyzeImage_primaryLow_secondaryHigher() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.analyzeImageResult = .success(Self.responseJSON(confidence: 40, marker: "P"))
        secondary.analyzeImageResult = .success(Self.responseJSON(confidence: 85, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.analyzeImage(imageData: "data:image/png;base64,AAA", prompt: "what is this")

        #expect(result.contains("\"source\":\"S\""))
    }

    @Test("analyzeImage: primary throws, secondary succeeds", .tags(.p1Core, .aiServices, .unit))
    func analyzeImage_primaryThrows_secondaryReturns() async throws {
        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.analyzeImageResult = .failure(MockLLMError.generic)
        secondary.analyzeImageResult = .success(Self.responseJSON(confidence: 80, marker: "S"))

        let service = Self.makeService(primary: primary, secondary: secondary)
        let result = try await service.analyzeImage(imageData: "data:image/png;base64,AAA", prompt: "what is this")

        #expect(result.contains("\"source\":\"S\""))
    }

    // MARK: - for(_:) request scoping

    @Test("for(request) returns a request-scoped fallback service", .tags(.p1Core, .aiServices, .unit))
    func forRequest_returnsScopedService() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app

        let primary = MockLLMService()
        let secondary = MockLLMService()
        primary.generateResult = .success(Self.responseJSON(confidence: 90, marker: "P"))

        let service = Self.makeService(primary: primary, secondary: secondary)

        // Build a synthetic Request to test for(_:)
        let req = Request(application: app, on: app.eventLoopGroup.next())
        let scoped = service.for(req)

        #expect(scoped is LLMFallbackService)
        let result = try await scoped.generate(input: "hello")
        #expect(result.contains("\"source\":\"P\""))

        try await app.asyncShutdown()
    }
}

// MARK: - Test-local mock

private enum MockLLMError: Error, Equatable {
    case generic
    case primaryOnly
    case secondaryOnly
}

private final class MockLLMService: LLMService, @unchecked Sendable {
    var generateResult: Result<String, Error> = .success("")
    var analyzeImageResult: Result<String, Error> = .success("")

    var generateCallCount: Int = 0
    var analyzeImageCallCount: Int = 0

    func generate(input: String) async throws -> String {
        generateCallCount += 1
        switch generateResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    func analyzeImage(imageData: String, prompt: String) async throws -> String {
        analyzeImageCallCount += 1
        switch analyzeImageResult {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    func `for`(_ request: Request) -> LLMService {
        self
    }
}

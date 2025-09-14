@testable import App
import Vapor

/// Fake Gemini service implementing LLMService for tests that specifically
/// want to refer to a Gemini-named fake. Internally reuses FakeLLMService behavior.
final class FakeGeminiService: LLMService, @unchecked Sendable {
    private let inner: FakeLLMService

    init(app: Application) {
        self.inner = FakeLLMService(app: app)
    }

    func generate(input: String) async throws -> String {
        try await inner.generate(input: input)
    }

    func analyzeImage(imageData: String, prompt: String) async throws -> String {
        try await inner.analyzeImage(imageData: imageData, prompt: prompt)
    }

    func `for`(_ request: Request) -> LLMService { self }
}


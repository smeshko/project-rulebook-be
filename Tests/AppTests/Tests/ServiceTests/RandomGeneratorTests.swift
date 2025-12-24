@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct RandomGeneratorTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    
    init() async throws {
        testWorld = try await IsolatedTestWorld()
        self.app = testWorld.app
    }
    
    @Test("Random generator service is properly configured")
    func serviceConfiguration() async throws {
        let defaultGenerator = app.randomGeneratorService

        // In testing environment, we expect a rigged generator for predictable tests
        #expect(type(of: defaultGenerator) == RiggedRandomGeneratorService.self)
    }

    @Test("Random generator can generate tokens of specified bit lengths")
    func generateTokensWithDifferentBitLengths() async throws {
        let generator = app.randomGeneratorService

        // Test different bit lengths
        let token64 = generator.generate(bits: 64)
        let token128 = generator.generate(bits: 128)
        let token256 = generator.generate(bits: 256)

        // Assert tokens are generated (not empty)
        #expect(!token64.isEmpty)
        #expect(!token128.isEmpty)
        #expect(!token256.isEmpty)

        // In testing environment, rigged generator might return same values
        // Just verify they are valid strings
        #expect(token64.count > 0)
        #expect(token128.count > 0)
        #expect(token256.count > 0)
    }

    @Test("Random generator produces consistent behavior for request context")
    func requestContextBehavior() async throws {
        _ = Request(
            application: app,
            method: .GET,
            url: "http://localhost/test",
            on: app.eventLoopGroup.next()
        )

        let generator = app.randomGeneratorService
        let token = generator.generate(bits: 128)

        #expect(!token.isEmpty)
        // In testing environment, we expect the rigged generator
        #expect(type(of: generator) == RiggedRandomGeneratorService.self)
    }
}

@testable import App
import XCTVapor
import Testing

struct RandomGeneratorTests {
    let app: Application
    let testWorld: TestWorld
    
    init() async throws {
        self.app = try TestWorld.makeTestAppSync()
        self.testWorld = try .init(app: app)
    }
    
    @Test("Random generator service is properly configured")
    func serviceConfiguration() async throws {
        let defaultGenerator = try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
        
        // In testing environment, we expect a rigged generator for predictable tests
        #expect(type(of: defaultGenerator) == RiggedRandomGeneratorService.self)
    }
    
    @Test("Random generator can generate tokens of specified bit lengths")
    func generateTokensWithDifferentBitLengths() async throws {
        let generator = try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
        
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
        let request = Request(
            application: app,
            method: .GET,
            url: "http://localhost/test",
            on: app.eventLoopGroup.next()
        )
        
        let generator = try await app.serviceRegistry.resolveRequired(RandomGeneratorService.self)
        let token = generator.generate(bits: 128)
        
        #expect(!token.isEmpty)
        // In testing environment, we expect the rigged generator
        #expect(type(of: generator) == RiggedRandomGeneratorService.self)
    }
}

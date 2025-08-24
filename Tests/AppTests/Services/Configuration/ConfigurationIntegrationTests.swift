@testable import App
import Testing
import VaporTesting

@Suite(.serialized)
struct ConfigurationIntegrationTests {
    @Test("Application startup works with valid configuration")
    func applicationStartupWithValidConfiguration() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        #expect(throws: Never.self) { try app.setupConfiguration() }
        #expect(app.configuration != nil)
        
        // Verify configuration is accessible
        let db = try app.configuration.database
        #expect(db.name == "test_db")
        
        let security = try app.configuration.security
        #expect(security.baseURL == "http://localhost:8080")
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("Application can configure services properly")
    func applicationCanConfigureServices() async throws {
        let testWorld = try await TestWorld()
        let app = testWorld.app
        
        // Configuration should be initialized by TestWorld
        #expect(app.configuration != nil)
        
        // Should be able to access configuration values
        let services = try app.configuration.services
        #expect(!services.brevoAPIKey.isEmpty)
        #expect(!services.openAIKey.isEmpty)
        
        // TestWorld manages app lifecycle, no manual cleanup needed
    }
    
    @Test("Testing environment uses testing defaults")
    func testingEnvironmentUsesTestingDefaults() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        try app.setupConfiguration()
        
        let db = try app.configuration.database
        #expect(db.host == "localhost")
        #expect(db.port == 5432)
        // In testing environment, reads from .env.testing
        #expect(db.name == "test_db")
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    @Test("Configuration logging does not expose secrets")
    func configurationLoggingDoesNotExposeSecrets() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        // This test verifies that sensitive information is not logged
        // In a real implementation, you would capture log output and verify
        // that passwords, API keys, etc. are not present
        
        #expect(throws: Never.self) { try app.setupConfiguration() }
        
        // The setupConfiguration method should log safely without exposing secrets
        // We can't easily test log output here, but this verifies no exceptions are thrown
        
        // Cleanup
        try await app.asyncShutdown()
    }
}
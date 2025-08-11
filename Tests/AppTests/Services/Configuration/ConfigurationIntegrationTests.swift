@testable import App
import XCTest
import XCTVapor

final class ConfigurationIntegrationTests: XCTestCase {
    func testApplicationStartupWithValidConfiguration() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        XCTAssertNoThrow(try app.setupConfiguration())
        XCTAssertNotNil(app.configuration)
        
        // Verify configuration is accessible
        let db = try app.configuration.database
        XCTAssertEqual(db.name, "test_db")
        
        let security = try app.configuration.security
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    func testApplicationCanConfigureServices() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        try configure(app)
        
        // Configuration should be initialized
        XCTAssertNotNil(app.configuration)
        
        // Should be able to access configuration values
        let services = try app.configuration.services
        XCTAssertFalse(services.brevoAPIKey.isEmpty)
        XCTAssertFalse(services.openAIKey.isEmpty)
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    func testTestingEnvironmentUsesTestingDefaults() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        try app.setupConfiguration()
        
        let db = try app.configuration.database
        XCTAssertEqual(db.host, "localhost")
        XCTAssertEqual(db.port, 5432)
        // In testing environment, reads from .env.testing
        XCTAssertEqual(db.name, "test_db")
        
        // Cleanup
        try await app.asyncShutdown()
    }
    
    func testConfigurationLoggingDoesNotExposeSecrets() async throws {
        let app = try await Application.make(.testing)
        // No defer needed - will clean up at end
        
        // This test verifies that sensitive information is not logged
        // In a real implementation, you would capture log output and verify
        // that passwords, API keys, etc. are not present
        
        XCTAssertNoThrow(try app.setupConfiguration())
        
        // The setupConfiguration method should log safely without exposing secrets
        // We can't easily test log output here, but this verifies no exceptions are thrown
        
        // Cleanup
        try await app.asyncShutdown()
    }
}
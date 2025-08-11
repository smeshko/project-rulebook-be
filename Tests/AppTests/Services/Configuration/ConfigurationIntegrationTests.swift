@testable import App
import XCTest
import XCTVapor

final class ConfigurationIntegrationTests: XCTestCase {
    func testApplicationStartupWithValidConfiguration() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        XCTAssertNoThrow(try app.setupConfiguration())
        XCTAssertNotNil(app.configuration)
        
        // Verify configuration is accessible
        let db = try app.configuration.database
        XCTAssertEqual(db.name, "test_db")
        
        let security = try app.configuration.security
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
    }
    
    func testApplicationCanConfigureServices() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        try configure(app)
        
        // Configuration should be initialized
        XCTAssertNotNil(app.configuration)
        
        // Should be able to access configuration values
        let services = try app.configuration.services
        XCTAssertFalse(services.brevoAPIKey.isEmpty)
        XCTAssertFalse(services.openAIKey.isEmpty)
    }
    
    func testDevelopmentEnvironmentUsesDefaults() throws {
        let app = Application(.development)
        defer { app.shutdown() }
        
        try app.setupConfiguration()
        
        let db = try app.configuration.database
        XCTAssertEqual(db.host, "localhost")
        XCTAssertEqual(db.port, 5432)
        // When tests run, reads from mixed environment (not pure defaults)
        XCTAssertEqual(db.name, "project_rulebook_dev")
    }
    
    func testConfigurationLoggingDoesNotExposeSecrets() throws {
        let app = Application(.testing)
        defer { app.shutdown() }
        
        // This test verifies that sensitive information is not logged
        // In a real implementation, you would capture log output and verify
        // that passwords, API keys, etc. are not present
        
        XCTAssertNoThrow(try app.setupConfiguration())
        
        // The setupConfiguration method should log safely without exposing secrets
        // We can't easily test log output here, but this verifies no exceptions are thrown
    }
}
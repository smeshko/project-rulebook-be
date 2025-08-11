@testable import App
import XCTest
import Vapor

final class ConfigurationTests: XCTestCase {
    
    func testDevelopmentConfigurationDefaults() throws {
        // This test runs in testing environment but tests development config behavior
        // Since we're in testing, we expect testing environment variables to be loaded
        // The development config will read those testing values, not its own defaults
        let config = DevelopmentConfiguration(environment: .development)
        
        let db = try config.database
        XCTAssertEqual(db.host, "localhost")
        XCTAssertEqual(db.port, 5432)
        // In testing environment, reads mixed values from current env
        XCTAssertEqual(db.name, "project_rulebook_dev")
        XCTAssertEqual(db.username, "vapor")
        XCTAssertEqual(db.password, "password")
        
        let services = try config.services
        XCTAssertEqual(services.brevoURL, "https://api.brevo.com")
        XCTAssertEqual(services.brevoAPIKey, "test_brevo_key")  // This one comes from .env.testing
        XCTAssertTrue(services.openAIKey.hasPrefix("sk-"))  // Real API key, just verify format
        
        let security = try config.security
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        XCTAssertEqual(security.appIdentifier, "com.dev.app")
        XCTAssertTrue(security.jwtKey.count >= 16)
        
        let aws = try config.aws
        XCTAssertEqual(aws.region, "us-west-2")
        XCTAssertEqual(aws.s3BucketName, "test-bucket")  // From .env.testing
        
        let cache = try config.cache
        XCTAssertEqual(cache.maxEntries, 100)  // From .env.testing
        XCTAssertEqual(cache.rulesGenerationTTL, 300.0)  // From .env.testing
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testTestingConfigurationProvidesSensibleDefaults() throws {
        let config = TestingConfiguration(environment: .testing)
        
        let db = try config.database
        XCTAssertEqual(db.name, "test_db")
        XCTAssertEqual(db.host, "localhost")
        
        let security = try config.security
        XCTAssertEqual(security.jwtKey, "test_jwt_key_32_characters_long!")
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        
        let services = try config.services
        XCTAssertEqual(services.brevoAPIKey, "test_brevo_key")
        XCTAssertEqual(services.openAIKey, "test_openai_key")
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testConfigurationFactoryCreatesDifferentTypesForEnvironments() {
        let devConfig = ConfigurationFactory.create(for: .development)
        XCTAssertTrue(devConfig is DevelopmentConfiguration)
        
        let prodConfig = ConfigurationFactory.create(for: .production)
        XCTAssertTrue(prodConfig is ProductionConfiguration)
        
        let stagingConfig = ConfigurationFactory.create(for: .staging)
        XCTAssertTrue(stagingConfig is ProductionConfiguration)
        
        let testConfig = ConfigurationFactory.create(for: .testing)
        XCTAssertTrue(testConfig is TestingConfiguration)
    }
    
    func testDevelopmentConfigurationValidation() throws {
        let config = DevelopmentConfiguration(environment: .development)
        
        // Valid configuration should pass validation
        XCTAssertNoThrow(try config.validate())
        
        // Test that validation works for all config sections
        let db = try config.database
        XCTAssertTrue(db.port > 0 && db.port <= 65535)
        
        let security = try config.security
        XCTAssertTrue(security.jwtKey.count >= 16) // Development minimum
    }
    
    func testTestingConfigurationValidation() throws {
        let config = TestingConfiguration(environment: .testing)
        
        XCTAssertNoThrow(try config.validate())
        
        // Verify testing-specific configurations
        let db = try config.database
        XCTAssertTrue(db.name.contains("test"))
        
        let security = try config.security
        XCTAssertEqual(security.jwtKey.count, 32) // Testing has fixed 32-char key
    }
    
    func testCacheConfigurationDefaults() throws {
        let devConfig = DevelopmentConfiguration(environment: .development)
        let cache = try devConfig.cache
        
        // In testing environment, development config reads testing values
        XCTAssertEqual(cache.maxEntries, 100)  // From .env.testing
        XCTAssertEqual(cache.rulesGenerationTTL, 300.0)  // From .env.testing 
        XCTAssertEqual(cache.imageAnalysisTTL, 300.0)    // From .env.testing
        XCTAssertEqual(cache.cleanupInterval, 60.0)      // From .env.testing
        XCTAssertFalse(cache.enableLogging)  // From .env.testing
        
        let testConfig = TestingConfiguration(environment: .testing)
        let testCache = try testConfig.cache
        
        XCTAssertEqual(testCache.maxEntries, 100)
        XCTAssertEqual(testCache.rulesGenerationTTL, 300.0)  // 5 minutes
        XCTAssertEqual(testCache.imageAnalysisTTL, 300.0)    // 5 minutes
        XCTAssertFalse(testCache.enableLogging) // Disabled in tests
    }
    
    func testSecurityConfigurationDefaults() throws {
        let devConfig = DevelopmentConfiguration(environment: .development)
        let security = try devConfig.security
        
        // Check CORS origins
        XCTAssertTrue(security.corsAllowedOrigins.contains("http://localhost:3000"))
        XCTAssertTrue(security.corsAllowedOrigins.contains("http://localhost:8080"))
        
        // Check rate limiting - reads from .env.testing
        XCTAssertEqual(security.rateLimitMaxRequests, 1000)  // From .env.testing
        XCTAssertEqual(security.rateLimitWindowMinutes, 1)
        
        let testConfig = TestingConfiguration(environment: .testing)
        let testSecurity = try testConfig.security
        
        // Test environment should have lenient rate limits
        XCTAssertEqual(testSecurity.rateLimitMaxRequests, 1000)
        XCTAssertEqual(testSecurity.rateLimitWindowMinutes, 1)
    }
    
    func testAWSConfigurationDefaults() throws {
        let devConfig = DevelopmentConfiguration(environment: .development)
        let aws = try devConfig.aws
        
        XCTAssertEqual(aws.region, "us-west-2")
        // Reads from .env.testing when running tests
        XCTAssertEqual(aws.s3BucketName, "test-bucket")
        XCTAssertEqual(aws.accessKey, "test_access_key")
        
        let testConfig = TestingConfiguration(environment: .testing)
        let testAWS = try testConfig.aws
        
        XCTAssertEqual(testAWS.region, "us-west-2")
        XCTAssertEqual(testAWS.s3BucketName, "test-bucket")
    }
    
    func testAPNSConfigurationDefaults() throws {
        let devConfig = DevelopmentConfiguration(environment: .development)
        let apns = try devConfig.apns
        
        // Reads from .env.testing when running tests
        XCTAssertEqual(apns.teamId, "TEST_TEAM_ID")
        XCTAssertEqual(apns.key, "test_apns_key")
        
        let testConfig = TestingConfiguration(environment: .testing)
        let testAPNS = try testConfig.apns
        
        XCTAssertEqual(testAPNS.teamId, "TEST_TEAM_ID")
    }
    
    // Test that production configuration requires environment variables
    // Note: We can't easily test production config validation without setting
    // actual environment variables, but we can test the factory selection
    func testProductionConfigurationRequiresStrictValidation() throws {
        let prodConfig = ConfigurationFactory.create(for: .production)
        XCTAssertTrue(prodConfig is ProductionConfiguration)
        
        // Production configuration should be more strict than development
        // This test verifies the correct type is created
        let stagingConfig = ConfigurationFactory.create(for: .staging)
        XCTAssertTrue(stagingConfig is ProductionConfiguration)
    }
}
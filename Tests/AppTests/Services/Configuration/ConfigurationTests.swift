import Vapor
import XCTest

@testable import App

final class ConfigurationTests: XCTestCase {
    
    func testDevelopmentConfigurationDefaults() async throws {
        // Test development configuration behavior - this test verifies what development
        // configuration returns with current environment variables. It uses the .env file loaded
        // for the given environemtn, in this case .env.testing
        try await setupApp()
        let config = DevelopmentConfiguration()
        
        let db = try config.database
        XCTAssertEqual(db.host, "localhost")
        XCTAssertEqual(db.port, 5432)
        // DevelopmentConfiguration uses environment variables when set, fallbacks otherwise
        XCTAssertEqual(db.name, "test_db")  // From DATABASE_NAME env.testing var
        XCTAssertEqual(db.username, "test_user")  // From DATABASE_USERNAME env.testing var
        XCTAssertEqual(db.password, "test_password")  // From DATABASE_PASSWORD env.testing var
        
        let services = try config.services
        XCTAssertEqual(services.brevoURL, "https://api.brevo.com")
        XCTAssertEqual(services.brevoAPIKey, "test_brevo_key")  // From .env.testing (loaded by test suite)
        // OpenAI key is from actual environment variable
        XCTAssertTrue(services.openAIKey.hasPrefix("sk-"))  // Real OpenAI API key from environment
        
        let security = try config.security
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        XCTAssertEqual(security.appIdentifier, "com.dev.app")
        XCTAssertTrue(security.jwtKey.count >= 16)
        
        let aws = try config.aws
        XCTAssertEqual(aws.region, "us-west-2")
        XCTAssertEqual(aws.s3BucketName, "test-bucket")  // From .env.testing (loaded by test suite)
        
        let cache = try config.cache
        XCTAssertEqual(cache.maxEntries, 100)  // From .env.testing (loaded by test suite)
        XCTAssertEqual(cache.rulesGenerationTTL, 300.0)  // From .env.testing (loaded by test suite)
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testTestingConfigurationProvidesSensibleDefaults() throws {
        let config = TestingConfiguration()
        
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
        let config = DevelopmentConfiguration()
        
        // Valid configuration should pass validation
        XCTAssertNoThrow(try config.validate())
        
        // Test that validation works for all config sections
        let db = try config.database
        XCTAssertTrue(db.port > 0 && db.port <= 65535)
        
        let security = try config.security
        XCTAssertTrue(security.jwtKey.count >= 16)  // Development minimum
    }
    
    func testTestingConfigurationValidation() throws {
        let config = TestingConfiguration()
        
        XCTAssertNoThrow(try config.validate())
        
        // Verify testing-specific configurations
        let db = try config.database
        XCTAssertTrue(db.name.contains("test"))
        
        let security = try config.security
        XCTAssertEqual(security.jwtKey.count, 32)  // Testing has fixed 32-char key
    }
    
    func testCacheConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let cache = try devConfig.cache
        
        // DevelopmentConfiguration uses .env.testing values when they're loaded
        XCTAssertEqual(cache.maxEntries, 100)  // From .env.testing
        XCTAssertEqual(cache.rulesGenerationTTL, 300.0)  // From .env.testing
        XCTAssertEqual(cache.imageAnalysisTTL, 300.0)  // From .env.testing
        XCTAssertEqual(cache.cleanupInterval, 60.0)  // From .env.testing
        XCTAssertFalse(cache.enableLogging)  // From .env.testing (disabled)
        
        let testConfig = TestingConfiguration()
        let testCache = try testConfig.cache
        
        XCTAssertEqual(testCache.maxEntries, 100)
        XCTAssertEqual(testCache.rulesGenerationTTL, 300.0)  // 5 minutes
        XCTAssertEqual(testCache.imageAnalysisTTL, 300.0)  // 5 minutes
        XCTAssertFalse(testCache.enableLogging)  // Disabled in tests
    }
    
    func testSecurityConfigurationDefaults() throws {
        let devConfig = DevelopmentConfiguration()
        let security = try devConfig.security
        
        // Check CORS origins
        XCTAssertTrue(security.corsAllowedOrigins.contains("http://localhost:3000"))
        XCTAssertTrue(security.corsAllowedOrigins.contains("http://localhost:8080"))
        
        // Check rate limiting - from .env.testing when loaded
        XCTAssertEqual(security.rateLimitMaxRequests, 1000)  // From .env.testing
        XCTAssertEqual(security.rateLimitWindowMinutes, 1)
        
        let testConfig = TestingConfiguration()
        let testSecurity = try testConfig.security
        
        // Test environment should have lenient rate limits
        XCTAssertEqual(testSecurity.rateLimitMaxRequests, 1000)
        XCTAssertEqual(testSecurity.rateLimitWindowMinutes, 1)
    }
    
    func testAWSConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let aws = try devConfig.aws
        
        XCTAssertEqual(aws.region, "us-west-2")
        // From .env.testing when loaded
        XCTAssertEqual(aws.s3BucketName, "test-bucket")
        XCTAssertEqual(aws.accessKey, "test_access_key")
        
        let testConfig = TestingConfiguration()
        let testAWS = try testConfig.aws
        
        XCTAssertEqual(testAWS.region, "us-west-2")
        XCTAssertEqual(testAWS.s3BucketName, "test-bucket")
    }
    
    func testAPNSConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let apns = try devConfig.apns
        
        // From .env.testing when loaded
        XCTAssertEqual(apns.teamId, "TEST_TEAM_ID")
        XCTAssertEqual(apns.key, "test_apns_key")
        
        let testConfig = TestingConfiguration()
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
    
    private func setupApp() async throws {
        let app = try await Application.make(.testing)
        try configure(app)
        try await app.asyncShutdown()
    }
}

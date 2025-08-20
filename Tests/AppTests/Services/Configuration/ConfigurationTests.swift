import Vapor
import Testing

@testable import App

@Suite(.serialized)
struct ConfigurationTests {
    
    @Test("Development configuration provides correct defaults from environment")
    func developmentConfigurationDefaults() async throws {
        // Test development configuration behavior - this test verifies what development
        // configuration returns with current environment variables. It uses the .env file loaded
        // for the given environemtn, in this case .env.testing
        try await setupApp()
        let config = DevelopmentConfiguration()
        
        let db = try config.database
        #expect(db.host == "localhost")
        #expect(db.port == 5432)
        // DevelopmentConfiguration uses environment variables when set, fallbacks otherwise
        #expect(db.name == "test_db")  // From DATABASE_NAME env.testing var
        #expect(db.username == "test_user")  // From DATABASE_USERNAME env.testing var
        #expect(db.password == "test_password")  // From DATABASE_PASSWORD env.testing var
        
        let services = try config.services
        #expect(services.brevoURL == "https://api.brevo.com")
        #expect(services.brevoAPIKey == "test_brevo_key")  // From .env.testing (loaded by test suite)
        // OpenAI key from .env.testing
        #expect(services.openAIKey == "test_openai_key")  // From .env.testing
        
        let security = try config.security
        #expect(security.baseURL == "http://localhost:8080")
        #expect(security.appIdentifier == "com.dev.app")
        #expect(security.jwtKey.count >= 16)
        
        let aws = try config.aws
        #expect(aws.region == "us-west-2")
        #expect(aws.s3BucketName == "test-bucket")  // From .env.testing (loaded by test suite)
        
        let cache = try config.cache
        #expect(cache.maxEntries == 100)  // From .env.testing (loaded by test suite)
        #expect(cache.rulesGenerationTTL == 300.0)  // From .env.testing (loaded by test suite)
        
        #expect(throws: Never.self) { try config.validate() }
    }
    
    @Test("Testing configuration provides sensible defaults")
    func testingConfigurationProvidesSensibleDefaults() async throws {
        let config = TestingConfiguration()
        
        let db = try config.database
        #expect(db.name == "test_db")
        #expect(db.host == "localhost")
        
        let security = try config.security
        #expect(security.jwtKey == "test_jwt_key_32_characters_long!")
        #expect(security.baseURL == "http://localhost:8080")
        
        let services = try config.services
        #expect(services.brevoAPIKey == "test_brevo_key")
        #expect(services.openAIKey == "test_openai_key")
        
        #expect(throws: Never.self) { try config.validate() }
    }
    
    @Test("Configuration factory creates different types for environments")
    func configurationFactoryCreatesDifferentTypesForEnvironments() {
        let devConfig = ConfigurationFactory.create(for: .development)
        #expect(devConfig is DevelopmentConfiguration)
        
        let prodConfig = ConfigurationFactory.create(for: .production)
        #expect(prodConfig is ProductionConfiguration)
        
        let stagingConfig = ConfigurationFactory.create(for: .staging)
        #expect(stagingConfig is ProductionConfiguration)
        
        let testConfig = ConfigurationFactory.create(for: .testing)
        #expect(testConfig is TestingConfiguration)
    }
    
    @Test("Development configuration validation works correctly")
    func developmentConfigurationValidation() async throws {
        let config = DevelopmentConfiguration()
        
        // Valid configuration should pass validation
        #expect(throws: Never.self) { try config.validate() }
        
        // Test that validation works for all config sections
        let db = try config.database
        #expect(db.port > 0 && db.port <= 65535)
        
        let security = try config.security
        #expect(security.jwtKey.count >= 16)  // Development minimum
    }
    
    @Test("Testing configuration validation works correctly")
    func testingConfigurationValidation() async throws {
        let config = TestingConfiguration()
        
        #expect(throws: Never.self) { try config.validate() }
        
        // Verify testing-specific configurations
        let db = try config.database
        #expect(db.name.contains("test"))
        
        let security = try config.security
        #expect(security.jwtKey.count == 32)  // Testing has fixed 32-char key
    }
    
    @Test("Cache configuration provides correct defaults")
    func cacheConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let cache = try devConfig.cache
        
        // DevelopmentConfiguration uses .env.testing values when they're loaded
        #expect(cache.maxEntries == 100)  // From .env.testing
        #expect(cache.rulesGenerationTTL == 300.0)  // From .env.testing
        #expect(cache.imageAnalysisTTL == 300.0)  // From .env.testing
        #expect(cache.cleanupInterval == 60.0)  // From .env.testing
        #expect(cache.enableLogging == false)  // From .env.testing (disabled)
        
        let testConfig = TestingConfiguration()
        let testCache = try testConfig.cache
        
        #expect(testCache.maxEntries == 100)
        #expect(testCache.rulesGenerationTTL == 300.0)  // 5 minutes
        #expect(testCache.imageAnalysisTTL == 300.0)  // 5 minutes
        #expect(testCache.enableLogging == false)  // Disabled in tests
    }
    
    @Test("Security configuration provides correct defaults")
    func securityConfigurationDefaults() async throws {
        let devConfig = DevelopmentConfiguration()
        let security = try devConfig.security
        
        // Check CORS origins
        #expect(security.corsAllowedOrigins.contains("http://localhost:3000"))
        #expect(security.corsAllowedOrigins.contains("http://localhost:8080"))
        
        // Check rate limiting - from .env.testing when loaded
        #expect(security.rateLimitMaxRequests == 1000)  // From .env.testing
        #expect(security.rateLimitWindowMinutes == 1)
        
        let testConfig = TestingConfiguration()
        let testSecurity = try testConfig.security
        
        // Test environment should have lenient rate limits
        #expect(testSecurity.rateLimitMaxRequests == 1000)
        #expect(testSecurity.rateLimitWindowMinutes == 1)
    }
    
    @Test("AWS configuration provides correct defaults")
    func awsConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let aws = try devConfig.aws
        
        #expect(aws.region == "us-west-2")
        // From .env.testing when loaded
        #expect(aws.s3BucketName == "test-bucket")
        #expect(aws.accessKey == "test_access_key")
        
        let testConfig = TestingConfiguration()
        let testAWS = try testConfig.aws
        
        #expect(testAWS.region == "us-west-2")
        #expect(testAWS.s3BucketName == "test-bucket")
    }
    
    @Test("APNS configuration provides correct defaults")
    func apnsConfigurationDefaults() async throws {
        try await setupApp()
        let devConfig = DevelopmentConfiguration()
        let apns = try devConfig.apns
        
        // From .env.testing when loaded
        #expect(apns.teamId == "TEST_TEAM_ID")
        #expect(apns.key == "test_apns_key")
        
        let testConfig = TestingConfiguration()
        let testAPNS = try testConfig.apns
        
        #expect(testAPNS.teamId == "TEST_TEAM_ID")
    }
    
    // Test that production configuration requires environment variables
    // Note: We can't easily test production config validation without setting
    // actual environment variables, but we can test the factory selection
    @Test("Production configuration requires strict validation")
    func productionConfigurationRequiresStrictValidation() async throws {
        let prodConfig = ConfigurationFactory.create(for: .production)
        #expect(prodConfig is ProductionConfiguration)
        
        // Production configuration should be more strict than development
        // This test verifies the correct type is created
        let stagingConfig = ConfigurationFactory.create(for: .staging)
        #expect(stagingConfig is ProductionConfiguration)
    }
    
    private func setupApp() async throws {
        let app = try await Application.make(.testing)
        try configure(app)
        try await app.asyncShutdown()
    }
}

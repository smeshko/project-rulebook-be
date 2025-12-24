import Vapor
import Testing

@testable import App

@Suite(.serialized)
struct ConfigurationTests {
    
    @Test("Development configuration provides correct defaults from environment")
    func developmentConfigurationDefaults() async throws {
        // Set up testing environment variables to simulate .env.testing being loaded
        setenv("DATABASE_NAME", "test_db", 1)
        setenv("DATABASE_USERNAME", "test_user", 1)
        setenv("DATABASE_PASSWORD", "test_password", 1)
        setenv("BREVO_API_KEY", "test_brevo_key", 1)
        setenv("OPENAI_KEY", "test_openai_key", 1)
        setenv("AWS_S3_BUCKET_NAME", "test-bucket", 1)
        setenv("CACHE_MAX_ENTRIES", "100", 1)
        setenv("CACHE_RULES_TTL", "300", 1)
        
        defer {
            // Clean up environment variables after test
            unsetenv("DATABASE_NAME")
            unsetenv("DATABASE_USERNAME")
            unsetenv("DATABASE_PASSWORD")
            unsetenv("BREVO_API_KEY")
            unsetenv("OPENAI_KEY")
            unsetenv("AWS_S3_BUCKET_NAME")
            unsetenv("CACHE_MAX_ENTRIES")
            unsetenv("CACHE_RULES_TTL")
        }
        
        let config = DevelopmentConfiguration()
        
        let db = try config.database
        #expect(db.host == "localhost")
        #expect(db.port == 5432)
        #expect(db.name == "test_db")
        #expect(db.username == "test_user")
        #expect(db.password == "test_password")
        
        let services = try config.services
        #expect(services.brevoURL == "https://api.brevo.com")
        #expect(services.brevoAPIKey == "test_brevo_key")
        #expect(services.openAIKey == "test_openai_key")
        
        let security = try config.security
        #expect(security.baseURL == "http://localhost:8080")
        #expect(security.appIdentifier == "com.dev.app")
        #expect(security.jwtKey.count >= 16)
        
        let aws = try config.aws
        #expect(aws.region == "us-west-2")
        #expect(aws.s3BucketName == "test-bucket")
        
        let cache = try config.cache
        #expect(cache.maxEntries == 100)
        #expect(cache.rulesGenerationTTL == 300.0)
        
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
        // Set up testing environment variables to simulate .env.testing being loaded
        setenv("CACHE_MAX_ENTRIES", "100", 1)
        setenv("CACHE_RULES_TTL", "300", 1)
        setenv("CACHE_IMAGE_TTL", "300", 1)
        setenv("CACHE_CLEANUP_INTERVAL", "60", 1)
        setenv("CACHE_ENABLE_LOGGING", "false", 1)
        
        defer {
            unsetenv("CACHE_MAX_ENTRIES")
            unsetenv("CACHE_RULES_TTL")
            unsetenv("CACHE_IMAGE_TTL")
            unsetenv("CACHE_CLEANUP_INTERVAL")
            unsetenv("CACHE_ENABLE_LOGGING")
        }
        
        let devConfig = DevelopmentConfiguration()
        let cache = try devConfig.cache
        
        #expect(cache.maxEntries == 100)
        #expect(cache.rulesGenerationTTL == 300.0)
        #expect(cache.cleanupInterval == 60.0)
        #expect(cache.enableLogging == false)

        let testConfig = TestingConfiguration()
        let testCache = try testConfig.cache

        #expect(testCache.maxEntries == 100)
        #expect(testCache.rulesGenerationTTL == 300.0)  // 5 minutes
        #expect(testCache.enableLogging == false)  // Disabled in tests
    }
    
    @Test("Security configuration provides correct defaults")
    func securityConfigurationDefaults() async throws {
        setenv("RATE_LIMIT_MAX_REQUESTS", "1000", 1)
        setenv("RATE_LIMIT_WINDOW_MINUTES", "1", 1)
        
        defer {
            unsetenv("RATE_LIMIT_MAX_REQUESTS")
            unsetenv("RATE_LIMIT_WINDOW_MINUTES")
        }
        
        let devConfig = DevelopmentConfiguration()
        let security = try devConfig.security
        
        // Check CORS origins
        #expect(security.corsAllowedOrigins.contains("http://localhost:3000"))
        #expect(security.corsAllowedOrigins.contains("http://localhost:8080"))
        
        // Check rate limiting
        #expect(security.rateLimitMaxRequests == 1000)
        #expect(security.rateLimitWindowMinutes == 1)
        
        let testConfig = TestingConfiguration()
        let testSecurity = try testConfig.security
        
        // Test environment should have lenient rate limits
        #expect(testSecurity.rateLimitMaxRequests == 1000)
        #expect(testSecurity.rateLimitWindowMinutes == 1)
    }
    
    @Test("AWS configuration provides correct defaults")
    func awsConfigurationDefaults() async throws {
        setenv("AWS_S3_BUCKET_NAME", "test-bucket", 1)
        setenv("AWS_ACCESS_KEY", "test_access_key", 1)
        
        defer {
            unsetenv("AWS_S3_BUCKET_NAME")
            unsetenv("AWS_ACCESS_KEY")
        }
        
        let devConfig = DevelopmentConfiguration()
        let aws = try devConfig.aws
        
        #expect(aws.region == "us-west-2")
        #expect(aws.s3BucketName == "test-bucket")
        #expect(aws.accessKey == "test_access_key")
        
        let testConfig = TestingConfiguration()
        let testAWS = try testConfig.aws
        
        #expect(testAWS.region == "us-west-2")
        #expect(testAWS.s3BucketName == "test-bucket")
    }
    
    @Test("APNS configuration provides correct defaults")
    func apnsConfigurationDefaults() async throws {
        setenv("APNS_TEAM_ID", "TEST_TEAM_ID", 1)
        setenv("APNS_KEY", "test_apns_key", 1)
        
        defer {
            unsetenv("APNS_TEAM_ID")
            unsetenv("APNS_KEY")
        }
        
        let devConfig = DevelopmentConfiguration()
        let apns = try devConfig.apns
        
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

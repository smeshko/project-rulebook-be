import Vapor

struct TestingConfiguration: ConfigurationService {
  var database: DatabaseConfig {
    get throws {
      DatabaseConfig(
        name: "test_db",
        host: "localhost",
        username: "test",
        password: "test",
        port: 5432
      )
    }
  }

  var services: ServicesConfig {
    get throws {
      ServicesConfig(
        brevoAPIKey: "test_brevo_key",
        brevoURL: "https://test.brevo.com",
        openAIKey: "test_openai_key",
        geminiApiKey: "test-gemini-api-key"
      )
    }
  }

  var security: SecurityConfig {
    get throws {
      return SecurityConfig(
        baseURL: "http://localhost:8080",
        appIdentifier: "com.test.app",
        jwtKey: "test_jwt_key_32_characters_long!",
        corsAllowedOrigins: ["http://localhost:3000", "http://localhost:8080"],
        rateLimitMaxRequests: 1000,  // Higher limit for testing
        rateLimitWindowMinutes: 1
      )
    }
  }

  var aws: AWSConfig {
    get throws {
      AWSConfig(
        accessKey: "test_access_key",
        secretAccessKey: "test_secret_key",
        region: "us-west-2",
        s3BucketName: "test-bucket"
      )
    }
  }

  var apns: APNSConfig {
    get throws {
      APNSConfig(
        key: "test_apns_key",
        privateKey: "test_private_key",
        teamId: "TEST_TEAM_ID"
      )
    }
  }

  var cache: CacheConfig {
    get throws {
      CacheConfig(
        maxEntries: 100,
        rulesGenerationTTL: 300,  // 5 minutes
        cleanupInterval: 60,  // 1 minute
        enableLogging: false  // Disabled for tests
      )
    }
  }
  
  var redis: RedisConfig {
    get throws {
      RedisConfig(
        host: "localhost",
        port: 6379,
        password: nil,
        database: 1,  // Use different database for tests
        poolSize: 2,
        connectionTimeout: 5.0,
        commandTimeout: 10.0,
        enableLogging: false  // Disabled for tests
      )
    }
  }

  var apple: AppleConfig {
    get throws {
      AppleConfig(
        issuerId: "test_issuer_id",
        keyId: "test_key_id",
        privateKey: "test_private_key",
        bundleId: "com.test.app",
        appAppleId: 123456789,
        environment: "sandbox"
      )
    }
  }

  var google: GooglePlayConfig {
    get throws {
      GooglePlayConfig(
        serviceAccountEmail: "test@test-project.iam.gserviceaccount.com",
        privateKey: "test_private_key",
        packageName: "com.test.app",
        pubsubVerificationToken: "test_pubsub_token"
      )
    }
  }

  func validate() throws {
    // Minimal validation for tests - all values are hardcoded and valid
  }
}

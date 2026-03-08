import Vapor

struct DevelopmentConfiguration: ConfigurationService {
  var database: DatabaseConfig {
    get throws {
      DatabaseConfig(
        name: Environment.get("DATABASE_NAME") ?? "dev_database",
        host: Environment.get("DATABASE_HOST") ?? "localhost",
        username: Environment.get("DATABASE_USERNAME") ?? "dev_user",
        password: Environment.get("DATABASE_PASSWORD") ?? "dev_password",
        port: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432
      )
    }
  }

  var services: ServicesConfig {
    get throws {
      ServicesConfig(
        brevoAPIKey: Environment.get("BREVO_API_KEY") ?? "dev_brevo_key",
        brevoURL: Environment.get("BREVO_URL") ?? "https://api.brevo.com",
        openAIKey: Environment.get("OPENAI_KEY") ?? "dev_openai_key",
        geminiApiKey: Environment.get("GEMINI_API_KEY") ?? "dev_gemini_key"
      )
    }
  }

  var security: SecurityConfig {
    get throws {
      let corsOrigins =
        Environment.get("CORS_ALLOWED_ORIGINS")?
        .split(separator: ",")
        .map(String.init) ?? ["http://localhost:3000", "http://localhost:8080"]

      return SecurityConfig(
        baseURL: Environment.get("BASE_URL") ?? "http://localhost:8080",
        appIdentifier: Environment.get("APPLICATION_IDENTIFIER") ?? "com.dev.app",
        jwtKey: Environment.get("JWT_KEY")
          ?? "development_jwt_secret_key_minimum_32_characters_required_for_security",
        corsAllowedOrigins: corsOrigins,
        rateLimitMaxRequests: Int(Environment.get("RATE_LIMIT_MAX_REQUESTS") ?? "100") ?? 100,
        rateLimitWindowMinutes: Int(Environment.get("RATE_LIMIT_WINDOW_MINUTES") ?? "1") ?? 1
      )
    }
  }

  var aws: AWSConfig {
    get throws {
      AWSConfig(
        accessKey: Environment.get("AWS_ACCESS_KEY") ?? "dev_access_key",
        secretAccessKey: Environment.get("AWS_SECRET_ACCESS_KEY") ?? "dev_secret_key",
        region: Environment.get("AWS_REGION") ?? "us-west-2",
        s3BucketName: Environment.get("AWS_S3_BUCKET_NAME") ?? "dev-bucket"
      )
    }
  }

  var apns: APNSConfig {
    get throws {
      APNSConfig(
        key: Environment.get("APNS_KEY") ?? "dev_apns_key",
        privateKey: Environment.get("APNS_PRIVATE_KEY") ?? "dev_private_key",
        teamId: Environment.get("APNS_TEAM_ID") ?? "DEV_TEAM_ID"
      )
    }
  }

  var cache: CacheConfig {
    get throws {
      CacheConfig(
        maxEntries: Int(Environment.get("CACHE_MAX_ENTRIES") ?? "500") ?? 500,
        rulesGenerationTTL: Double(Environment.get("CACHE_RULES_TTL") ?? "3600") ?? 3600,  // 1 hour
        cleanupInterval: Double(Environment.get("CACHE_CLEANUP_INTERVAL") ?? "300") ?? 300,  // 5 minutes
        enableLogging: Environment.get("CACHE_ENABLE_LOGGING")?.lowercased() != "false"  // Default enabled
      )
    }
  }
  
  var redis: RedisConfig {
    get throws {
      RedisConfig(
        host: Environment.get("REDIS_HOST") ?? "localhost",
        port: Int(Environment.get("REDIS_PORT") ?? "6379") ?? 6379,
        password: Environment.get("REDIS_PASSWORD"),
        database: Int(Environment.get("REDIS_DATABASE") ?? "0") ?? 0,
        poolSize: Int(Environment.get("REDIS_POOL_SIZE") ?? "5") ?? 5,
        connectionTimeout: Double(Environment.get("REDIS_CONNECTION_TIMEOUT") ?? "5.0") ?? 5.0,
        commandTimeout: Double(Environment.get("REDIS_COMMAND_TIMEOUT") ?? "10.0") ?? 10.0,
        enableLogging: Environment.get("REDIS_ENABLE_LOGGING")?.lowercased() != "false"
      )
    }
  }

  var apple: AppleConfig {
    get throws {
      AppleConfig(
        issuerId: Environment.get("APPLE_ISSUER_ID") ?? "dev_issuer_id",
        keyId: Environment.get("APPLE_KEY_ID") ?? "dev_key_id",
        privateKey: Environment.get("APPLE_PRIVATE_KEY") ?? "dev_private_key",
        bundleId: Environment.get("APP_BUNDLE_ID") ?? "com.dev.app",
        appAppleId: Int64(Environment.get("APP_APPLE_ID") ?? "123456789") ?? 123456789,
        environment: Environment.get("APPLE_ENVIRONMENT") ?? "sandbox"
      )
    }
  }

  func validate() throws {
    let db = try database

    // Minimal validation for development
    if db.port < 1 || db.port > 65535 {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_PORT",
        expected: "1-65535",
        got: "\(db.port)"
      )
    }

    let sec = try security
    if sec.jwtKey.count < 16 {
      throw ConfigurationError.validationFailed(
        component: "JWT",
        reason: "JWT key should be at least 16 characters for development"
      )
    }
  }
}

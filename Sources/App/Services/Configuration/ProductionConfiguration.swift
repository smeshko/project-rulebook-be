import Vapor
import Foundation

struct ProductionConfiguration: ConfigurationService {
  var database: DatabaseConfig {
    get throws {
      // First, try to parse DATABASE_URL (Railway format)
      if let databaseURL = Environment.get("DATABASE_URL") {
        return try parseDatabaseURL(databaseURL)
      }
      
      // Fallback to individual environment variables (local development)
      guard let name = Environment.get("DATABASE_NAME") else {
        throw ConfigurationError.missingRequired(
          key: "DATABASE_NAME or DATABASE_URL",
          suggestion: "Set DATABASE_URL for Railway deployment or individual DATABASE_* variables for local development"
        )
      }

      guard let host = Environment.get("DATABASE_HOST") else {
        throw ConfigurationError.missingRequired(
          key: "DATABASE_HOST",
          suggestion: "Set DATABASE_HOST environment variable for production database"
        )
      }

      guard let username = Environment.get("DATABASE_USERNAME") else {
        throw ConfigurationError.missingRequired(
          key: "DATABASE_USERNAME",
          suggestion: "Set DATABASE_USERNAME environment variable for production database"
        )
      }

      guard let password = Environment.get("DATABASE_PASSWORD") else {
        throw ConfigurationError.missingRequired(
          key: "DATABASE_PASSWORD",
          suggestion: "Set DATABASE_PASSWORD environment variable for production database"
        )
      }

      guard let portString = Environment.get("DATABASE_PORT"),
        let port = Int(portString)
      else {
        throw ConfigurationError.missingRequired(
          key: "DATABASE_PORT",
          suggestion: "Set DATABASE_PORT environment variable (e.g., 5432)"
        )
      }

      return DatabaseConfig(
        name: name,
        host: host,
        username: username,
        password: password,
        port: port
      )
    }
  }

  var services: ServicesConfig {
    get throws {
      guard let brevoAPIKey = Environment.get("BREVO_API_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "BREVO_API_KEY",
          suggestion: "Set BREVO_API_KEY environment variable for email service"
        )
      }

      guard let openAIKey = Environment.get("OPENAI_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "OPENAI_KEY",
          suggestion: "Set OPENAI_KEY environment variable for LLM service"
        )
      }

      guard let geminiKey = Environment.get("GEMINI_API_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "GEMINI_API_KEY",
          suggestion: "Set GEMINI_API_KEY environment variable for Gemini LLM service"
        )
      }

      return ServicesConfig(
        brevoAPIKey: brevoAPIKey,
        brevoURL: Environment.get("BREVO_URL") ?? "https://api.brevo.com",
        openAIKey: openAIKey,
        geminiApiKey: geminiKey
      )
    }
  }

  var security: SecurityConfig {
    get throws {
      guard let baseURL = Environment.get("BASE_URL") else {
        throw ConfigurationError.missingRequired(
          key: "BASE_URL",
          suggestion: "Set BASE_URL environment variable (e.g., https://yourdomain.com)"
        )
      }

      guard let appIdentifier = Environment.get("APPLICATION_IDENTIFIER") else {
        throw ConfigurationError.missingRequired(
          key: "APPLICATION_IDENTIFIER",
          suggestion: "Set APPLICATION_IDENTIFIER environment variable (e.g., com.yourcompany.app)"
        )
      }

      guard let jwtKey = Environment.get("JWT_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "JWT_KEY",
          suggestion: "Set JWT_KEY environment variable with a secure random key"
        )
      }

      let corsOrigins =
        Environment.get("CORS_ALLOWED_ORIGINS")?
        .split(separator: ",")
        .map(String.init) ?? []

      if corsOrigins.isEmpty {
        throw ConfigurationError.missingRequired(
          key: "CORS_ALLOWED_ORIGINS",
          suggestion:
            "Set CORS_ALLOWED_ORIGINS environment variable with comma-separated allowed origins"
        )
      }

      return SecurityConfig(
        baseURL: baseURL,
        appIdentifier: appIdentifier,
        jwtKey: jwtKey,
        corsAllowedOrigins: corsOrigins,
        rateLimitMaxRequests: Int(Environment.get("RATE_LIMIT_MAX_REQUESTS") ?? "100") ?? 100,
        rateLimitWindowMinutes: Int(Environment.get("RATE_LIMIT_WINDOW_MINUTES") ?? "1") ?? 1
      )
    }
  }

  var aws: AWSConfig {
    get throws {
      guard let accessKey = Environment.get("AWS_ACCESS_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "AWS_ACCESS_KEY",
          suggestion: "Set AWS_ACCESS_KEY environment variable for AWS services"
        )
      }

      guard let secretAccessKey = Environment.get("AWS_SECRET_ACCESS_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "AWS_SECRET_ACCESS_KEY",
          suggestion: "Set AWS_SECRET_ACCESS_KEY environment variable for AWS services"
        )
      }

      guard let region = Environment.get("AWS_REGION") else {
        throw ConfigurationError.missingRequired(
          key: "AWS_REGION",
          suggestion: "Set AWS_REGION environment variable (e.g., us-west-2)"
        )
      }

      guard let s3BucketName = Environment.get("AWS_S3_BUCKET_NAME") else {
        throw ConfigurationError.missingRequired(
          key: "AWS_S3_BUCKET_NAME",
          suggestion: "Set AWS_S3_BUCKET_NAME environment variable for file storage"
        )
      }

      return AWSConfig(
        accessKey: accessKey,
        secretAccessKey: secretAccessKey,
        region: region,
        s3BucketName: s3BucketName
      )
    }
  }

  var apns: APNSConfig {
    get throws {
      guard let key = Environment.get("APNS_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "APNS_KEY",
          suggestion: "Set APNS_KEY environment variable for push notifications"
        )
      }

      guard let privateKey = Environment.get("APNS_PRIVATE_KEY") else {
        throw ConfigurationError.missingRequired(
          key: "APNS_PRIVATE_KEY",
          suggestion: "Set APNS_PRIVATE_KEY environment variable for push notifications"
        )
      }

      guard let teamId = Environment.get("APNS_TEAM_ID") else {
        throw ConfigurationError.missingRequired(
          key: "APNS_TEAM_ID",
          suggestion: "Set APNS_TEAM_ID environment variable for push notifications"
        )
      }

      return APNSConfig(
        key: key,
        privateKey: privateKey,
        teamId: teamId
      )
    }
  }

  var cache: CacheConfig {
    get throws {
      CacheConfig(
        maxEntries: Int(Environment.get("CACHE_MAX_ENTRIES") ?? "1000") ?? 1000,
        rulesGenerationTTL: Double(Environment.get("CACHE_RULES_TTL") ?? "3600") ?? 3600,  // 1 hour
        imageAnalysisTTL: Double(Environment.get("CACHE_IMAGE_TTL") ?? "1800") ?? 1800,  // 30 minutes
        cleanupInterval: Double(Environment.get("CACHE_CLEANUP_INTERVAL") ?? "600") ?? 600,  // 10 minutes
        enableLogging: Environment.get("CACHE_ENABLE_LOGGING")?.lowercased() == "true"  // Default disabled for production
      )
    }
  }
  
  var redis: RedisConfig {
    get throws {
      // First, try to parse REDIS_URL (Railway format)
      if let redisURL = Environment.get("REDIS_URL") {
        return try parseRedisURL(redisURL)
      }
      
      // Fallback to individual environment variables (local development)
      guard let host = Environment.get("REDIS_HOST") else {
        throw ConfigurationError.missingRequired(
          key: "REDIS_HOST or REDIS_URL",
          suggestion: "Set REDIS_URL for Railway deployment or individual REDIS_* variables for local development"
        )
      }
      
      let port = Int(Environment.get("REDIS_PORT") ?? "6379") ?? 6379
      let database = Int(Environment.get("REDIS_DATABASE") ?? "0") ?? 0
      let poolSize = Int(Environment.get("REDIS_POOL_SIZE") ?? "20") ?? 20
      
      // Validate port range for individual env vars too
      guard port >= 1 && port <= 65535 else {
        throw ConfigurationError.invalidFormat(
          key: "REDIS_PORT",
          expected: "Port number between 1 and 65535",
          got: "\(port)"
        )
      }
      
      return RedisConfig(
        host: host,
        port: port,
        password: Environment.get("REDIS_PASSWORD"),
        database: database,
        poolSize: poolSize,
        connectionTimeout: Double(Environment.get("REDIS_CONNECTION_TIMEOUT") ?? "10.0") ?? 10.0,
        commandTimeout: Double(Environment.get("REDIS_COMMAND_TIMEOUT") ?? "30.0") ?? 30.0,
        enableLogging: Environment.get("REDIS_ENABLE_LOGGING")?.lowercased() == "true"
      )
    }
  }

  func validate() throws {
    let db = try database
    let services = try services
    let security = try security
    let cache = try cache
    _ = try aws
    _ = try apns

    // Database validation
    if db.port < 1 || db.port > 65535 {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_PORT",
        expected: "1-65535",
        got: "\(db.port)"
      )
    }

    // Security validation
    if security.jwtKey.count < 32 {
      throw ConfigurationError.validationFailed(
        component: "JWT",
        reason: "JWT key must be at least 32 characters for production"
      )
    }

    // URL validation
    guard security.baseURL.hasPrefix("http://") || security.baseURL.hasPrefix("https://") else {
      throw ConfigurationError.validationFailed(
        component: "Security",
        reason: "BASE_URL must be a valid URL with http:// or https:// scheme"
      )
    }

    // Services validation
    if services.brevoAPIKey.isEmpty {
      throw ConfigurationError.validationFailed(
        component: "Brevo",
        reason: "BREVO_API_KEY cannot be empty"
      )
    }

    if services.openAIKey.isEmpty {
      throw ConfigurationError.validationFailed(
        component: "OpenAI",
        reason: "OPENAI_KEY cannot be empty"
      )
    }

    if services.geminiApiKey.isEmpty {
      throw ConfigurationError.validationFailed(
        component: "Gemini",
        reason: "GEMINI_API_KEY cannot be empty"
      )
    }

    // Cache validation
    if cache.maxEntries < 1 {
      throw ConfigurationError.validationFailed(
        component: "Cache",
        reason: "CACHE_MAX_ENTRIES must be at least 1"
      )
    }

    if cache.rulesGenerationTTL < 60 {
      throw ConfigurationError.validationFailed(
        component: "Cache",
        reason: "CACHE_RULES_TTL must be at least 60 seconds"
      )
    }

    if cache.imageAnalysisTTL < 60 {
      throw ConfigurationError.validationFailed(
        component: "Cache",
        reason: "CACHE_IMAGE_TTL must be at least 60 seconds"
      )
    }
  }
  
  // MARK: - Private URL Parsing Methods
  
  /// Parses a PostgreSQL DATABASE_URL into DatabaseConfig
  /// Format: postgresql://username:password@host:port/database
  private func parseDatabaseURL(_ urlString: String) throws -> DatabaseConfig {
    guard let url = URL(string: urlString) else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "postgresql://username:password@host:port/database",
        got: urlString
      )
    }
    
    guard url.scheme == "postgresql" || url.scheme == "postgres" else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "postgresql:// or postgres:// scheme",
        got: url.scheme ?? "none"
      )
    }
    
    guard let host = url.host else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "Valid hostname",
        got: "missing host"
      )
    }
    
    guard let username = url.user else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "Username in URL",
        got: "missing username"
      )
    }
    
    guard let password = url.password else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "Password in URL",
        got: "missing password"
      )
    }
    
    let port = url.port ?? 5432
    
    // Extract database name from path (remove leading slash)
    let database = String(url.path.dropFirst())
    guard !database.isEmpty else {
      throw ConfigurationError.invalidFormat(
        key: "DATABASE_URL",
        expected: "Database name in URL path",
        got: "missing database name"
      )
    }
    
    return DatabaseConfig(
      name: database,
      host: host,
      username: username,
      password: password,
      port: port
    )
  }
  
  /// Parses a Redis REDIS_URL into RedisConfig
  /// Format: redis://[:password@]host:port[/database]
  private func parseRedisURL(_ urlString: String) throws -> RedisConfig {
    guard let url = URL(string: urlString) else {
      throw ConfigurationError.invalidFormat(
        key: "REDIS_URL",
        expected: "redis://[:password@]host:port[/database]",
        got: urlString
      )
    }
    
    guard url.scheme == "redis" || url.scheme == "rediss" else {
      throw ConfigurationError.invalidFormat(
        key: "REDIS_URL",
        expected: "redis:// or rediss:// scheme",
        got: url.scheme ?? "none"
      )
    }
    
    guard let host = url.host else {
      throw ConfigurationError.invalidFormat(
        key: "REDIS_URL",
        expected: "Valid hostname",
        got: "missing host"
      )
    }
    
    let port = url.port ?? 6379
    let password = url.password
    
    // Validate port range
    guard port >= 1 && port <= 65535 else {
      throw ConfigurationError.invalidFormat(
        key: "REDIS_URL",
        expected: "Port number between 1 and 65535",
        got: "\(port)"
      )
    }
    
    // Extract database number from path (remove leading slash and convert to int)
    var database = 0
    if !url.path.isEmpty {
      let databaseString = String(url.path.dropFirst())
      if !databaseString.isEmpty {
        database = Int(databaseString) ?? 0
      }
    }
    
    // Use environment variable overrides for connection settings, with sensible defaults
    let poolSize = Int(Environment.get("REDIS_POOL_SIZE") ?? "20") ?? 20
    let connectionTimeout = Double(Environment.get("REDIS_CONNECTION_TIMEOUT") ?? "10.0") ?? 10.0
    let commandTimeout = Double(Environment.get("REDIS_COMMAND_TIMEOUT") ?? "30.0") ?? 30.0
    let enableLogging = Environment.get("REDIS_ENABLE_LOGGING")?.lowercased() == "true"
    
    return RedisConfig(
      host: host,
      port: port,
      password: password,
      database: database,
      poolSize: poolSize,
      connectionTimeout: connectionTimeout,
      commandTimeout: commandTimeout,
      enableLogging: enableLogging
    )
  }
}

import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
@preconcurrency import JWT
@preconcurrency import Redis
import Vapor

extension String {
  fileprivate var bytes: [UInt8] { .init(self.utf8) }
}

extension JWKIdentifier {
  fileprivate static let `public` = JWKIdentifier(string: "public")
  fileprivate static let `private` = JWKIdentifier(string: "private")
}

extension Application {
  func setupConfiguration() throws {
    // Vapor automatically loads .env files during Environment.detect()
    // No manual parsing needed - Environment.get() reads from process environment
    try initializeConfiguration()

    // Log configuration status (without sensitive data)
    logger.info("Configuration loaded for environment: \(environment.name)")
    let db = try configuration.database
    logger.info("Database host: \(db.host)")
    logger.info("Services configured: Brevo, OpenAI + Gemini (fallback)")
  }

  func setupMiddleware() throws {
    middleware = .init()

    // Security middleware first
    let security = try configuration.security

    // CORS Configuration
    let corsConfiguration = CORSMiddleware.Configuration(
      allowedOrigin: .any(security.corsAllowedOrigins),
      allowedMethods: [.GET, .POST, .PUT, .DELETE, .PATCH, .OPTIONS],
      allowedHeaders: [
        .accept,
        .authorization,
        .contentType,
        .origin,
        .xRequestedWith,
        .userAgent,
        .accessControlRequestMethod,
        .accessControlRequestHeaders,
      ]
    )
    middleware.use(CORSMiddleware(configuration: corsConfiguration))
    
    // Correlation ID middleware for request tracing (replaces CorrelationIDAspect)
    middleware.use(CorrelationIDMiddleware())
    
    // Query performance monitoring removed - was unused by repositories
    // Future implementation should use Fluent's built-in query logging or database-level monitoring

    // Unified Rate Limiting with operation-specific limits
    let rateLimitConfig =
      environment == .production
      ? RateLimitConfiguration.production() : RateLimitConfiguration.development()
    middleware.use(RateLimitMiddleware(configuration: rateLimitConfig))

    // Security Headers
    middleware.use(SecurityHeadersMiddleware())

    // File serving (single instance)
    middleware.use(FileMiddleware(publicDirectory: directory.publicDirectory))

    // Body size limit
    routes.defaultMaxBodySize = "10mb"

    // Error handling
    middleware.use(ErrorMiddleware.custom(environment: environment))

    // Authentication
    middleware.use(UserPayloadAuthenticator())
  }
  

  func setupModules() throws {
    let modules: [ModuleInterface] = [
      HealthModule(),
      UserModule(),
      AuthModule(),
      FrontendModule(),
      RulesGenerationModule(),
      CacheAdminModule(),
      WaitlistModule(),
      RemoteConfigModule(),
      ReceiptsModule(),
      FeedbackModule(),
    ]

    for module in modules {
      try module.boot(self)
    }

    for module in modules {
      try module.setUp(self)
    }
  }

  func setupDB() throws {
    var tlsConnectionConfiguration: PostgresConnection.Configuration.TLS = .disable

    switch environment {
    case .testing:
      databases.use(.sqlite(.memory), as: .sqlite)
      return
    case .staging, .production:
      var tlsConfig: TLSConfiguration = .makeClientConfiguration()
      tlsConfig.certificateVerification = .none
      let nioSSLContext = try NIOSSLContext(configuration: tlsConfig)
      tlsConnectionConfiguration = .require(nioSSLContext)
    case .development:
      // Development uses PostgreSQL without TLS for local development
      tlsConnectionConfiguration = .disable
    default:
      break
    }

    let db = try configuration.database
    let postgresConfig = SQLPostgresConfiguration(
      hostname: db.host,
      port: db.port,
      username: db.username,
      password: db.password,
      database: db.name,
      tls: tlsConnectionConfiguration
    )
    
    // Configure connection pool settings based on environment
    let (maxConnections, poolTimeout) = environment == .development 
      ? (1, TimeAmount.seconds(10))  // Lighter settings for development
      : (2, TimeAmount.seconds(30))  // Production-ready settings
    
    databases.use(.postgres(
      configuration: postgresConfig,
      maxConnectionsPerEventLoop: maxConnections,
      connectionPoolTimeout: poolTimeout
    ), as: .psql)
  }

  func setupJWT() throws {
    if environment != .testing {
      let security = try configuration.security
      jwt.signers.use(.hs256(key: security.jwtKey))
    }
  }
  
  func setupRedis() throws {
    if environment == .testing {
      // Skip Redis setup for testing
      return
    }
    
    do {
      let redisConfig = try configuration.redis
      
      redis.configuration = try RedisConfiguration(
        hostname: redisConfig.host,
        port: redisConfig.port,
        password: redisConfig.password?.isEmpty == false ? redisConfig.password : nil,
        database: redisConfig.database,
        pool: RedisConfiguration.PoolOptions(
          maximumConnectionCount: .maximumActiveConnections(redisConfig.poolSize),
          connectionRetryTimeout: .seconds(Int64(redisConfig.connectionTimeout))
        )
      )
      
      logger.info("Redis configured successfully", metadata: [
        "host": .string(redisConfig.host),
        "port": .string("\(redisConfig.port)"),
        "database": .string("\(redisConfig.database)")
      ])
    } catch {
      logger.error("Failed to configure Redis", metadata: [
        "error": .string(String(describing: error))
      ])
      throw error
    }
  }

  func setupServices() throws {
    // Skip service setup for testing - tests configure their own services
    if environment == .testing {
      return
    }

    // Initialize repositories (database-backed)
    userRepository = DatabaseUserRepository(database: db)
    emailTokenRepository = DatabaseEmailTokenRepository(database: db)
    refreshTokenRepository = DatabaseRefreshTokenRepository(database: db)
    passwordTokenRepository = DatabasePasswordTokenRepository(database: db)
    generatedRuleRepository = DatabaseGeneratedRuleRepository(database: db)
    waitlistRepository = DatabaseWaitlistRepository(database: db)
    remoteConfigRepository = DatabaseRemoteConfigRepository(database: db)
    receiptsRepository = DatabaseReceiptsRepository(database: db)
    feedbackRepository = DatabaseFeedbackRepository(database: db)
    gameRequestStatsRepository = DatabaseGameRequestStatsRepository(database: db)

    // Initialize foundation services (no dependencies)
    randomGeneratorService = RealRandomGeneratorService(app: self)
    uuidGeneratorService = RealUUIDGeneratorService(app: self)
    ipExtractorService = DefaultIPExtractorService(app: self)
    cacheKeyGeneratorService = DefaultCacheKeyGeneratorService(app: self)
    promptSanitizerService = DefaultPromptSanitizerService(app: self)
    aiInputValidatorService = DefaultAIInputValidatorService(app: self)
    aiResponseValidatorService = DefaultAIResponseValidationService()

    // Initialize external services
    emailService = BrevoClient(app: self)

    // LLM services: OpenAI is primary, Gemini is secondary (fallback).
    // `llmService` exposes a fallback orchestrator that transparently retries
    // low-confidence primary responses against the secondary model.
    let primaryLLM = OpenAIService(app: self, logger: logger)
    let secondaryLLM = GoogleGeminiService(app: self, logger: logger)
    primaryLLMService = primaryLLM
    secondaryLLMService = secondaryLLM
    let confidenceThreshold = try configuration.services.aiConfidenceThreshold
    llmService = LLMFallbackService(
        primary: primaryLLM,
        secondary: secondaryLLM,
        threshold: confidenceThreshold,
        validator: aiResponseValidatorService,
        logger: logger,
        primaryName: "OpenAIService",
        secondaryName: "GoogleGeminiService"
    )
    logger.info("LLM fallback orchestrator configured", metadata: [
        "primary": .string("OpenAIService"),
        "secondary": .string("GoogleGeminiService"),
        "threshold": .string("\(confidenceThreshold)")
    ])

    appStoreValidationService = DefaultAppStoreValidationService(app: self)
    playStoreValidationService = DefaultPlayStoreValidationService(app: self)
    appleNotificationService = DefaultAppleNotificationService(app: self)
    googleNotificationService = DefaultGoogleNotificationService(app: self)

    // Initialize Redis-based services
    let redisConfig = try configuration.redis
    cacheService = RedisCacheService(
      redis: redis,
      configuration: redisConfig,
      logger: logger
    )
    aiCacheService = RedisAICacheService(
      cacheService: cacheService,
      keyGenerator: cacheKeyGeneratorService,
      logger: logger
    )
    remoteConfigCacheService = DefaultRemoteConfigCacheService(
      cacheService: cacheService,
      logger: logger
    )

    logger.info("Services initialized successfully")
  }

  func setupBackgroundJobs() {
    guard environment != .testing else { return }

    let job = PendingValidationJob(app: self)
    self.pendingValidationJob = job
    job.start()

    lifecycle.use(PendingValidationJobLifecycleHandler(job: job))

    let warmingJob = CacheWarmingJob(app: self)
    self.cacheWarmingJob = warmingJob
    warmingJob.start()

    lifecycle.use(CacheWarmingJobLifecycleHandler(job: warmingJob))

    logger.info("Background jobs started: PendingValidationJob, CacheWarmingJob")
  }
}

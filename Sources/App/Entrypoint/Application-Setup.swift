import FluentPostgresDriver
import FluentSQLiteDriver
import Foundation
@preconcurrency import JWT
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
    // Determine which .env file to load based on environment
    let workingDirectory = DirectoryConfiguration.detect().workingDirectory
    let envFilePath: String
    
    switch environment {
    case .testing:
      // Try .env.testing first, fallback to .env
      let testingEnvPath = workingDirectory + ".env.testing"
      if FileManager.default.fileExists(atPath: testingEnvPath) {
        envFilePath = testingEnvPath
      } else {
        envFilePath = workingDirectory + ".env"
      }
    default:
      envFilePath = workingDirectory + ".env"
    }
    
    // Load the environment file
    if FileManager.default.fileExists(atPath: envFilePath) {
      logger.info("Loading environment variables from \(envFilePath.split(separator: "/").last ?? "")")
      do {
        let envContent = try String(contentsOfFile: envFilePath, encoding: .utf8)
        for line in envContent.split(separator: "\n") {
          let trimmedLine = line.trimmingCharacters(in: .whitespaces)
          // Skip comments and empty lines
          if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
            continue
          }
          // Parse KEY=VALUE format
          if let equalIndex = trimmedLine.firstIndex(of: "=") {
            let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmedLine[trimmedLine.index(after: equalIndex)...])
              .trimmingCharacters(in: .whitespaces)
              .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

            // Set the environment variable
            setenv(key, value, 1)

            // Log non-sensitive keys
            if !key.lowercased().contains("key") && !key.lowercased().contains("secret")
              && !key.lowercased().contains("password")
            {
              logger.debug("Loaded env var: \(key)")
            } else {
              logger.debug("Loaded sensitive env var: \(key) (value hidden)")
            }
          }
        }
      } catch {
        logger.warning("Could not load \(envFilePath): \(error)")
      }
    } else {
      logger.info("No environment file found at \(envFilePath)")
    }

    try initializeConfiguration()

    // Log configuration status (without sensitive data)
    logger.info("Configuration loaded for environment: \(environment.name)")
    let db = try configuration.database
    logger.info("Database host: \(db.host)")
    logger.info("Services configured: Brevo, OpenAI")
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
    
    // Setup Aspect-Oriented Middleware for cross-cutting concerns
    setupAspects()
    
    // Add AspectMiddleware with registered aspects
    middleware.use(aspectRegistry.middleware())
    
    // Query performance monitoring (only in development/staging)
    if environment != .production {
        let queryConfig = environment == .development 
            ? QueryPerformanceMiddleware.Configuration.development 
            : QueryPerformanceMiddleware.Configuration.production
        middleware.use(QueryPerformanceMiddleware(configuration: queryConfig))
    }

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
  
  func setupAspects() {
    // Register aspects in priority order (higher priority = runs first)
    
    // Correlation ID should run first to ensure all logs have correlation ID
    // Note: UUIDGeneratorService will be available at runtime via service registry
    // For now, CorrelationIDAspect will fall back to system UUID generation
    aspectRegistry.register(
      CorrelationIDAspect(uuidGenerator: nil),
      priority: 1000
    )
    
    // Validation runs early to reject invalid requests quickly
    let validationConfig = environment == .production
      ? ValidationAspect.Configuration.production
      : ValidationAspect.Configuration.development
    aspectRegistry.register(
      ValidationAspect(configuration: validationConfig),
      priority: 500
    )
    
    // Error handling runs last to catch all errors
    aspectRegistry.register(
      ErrorHandlingAspect(environment: environment),
      priority: 100
    )
    
    logger.info("Registered \(aspectRegistry.all().count) aspects for cross-cutting concerns")
  }

  func setupModules() throws {
    let modules: [ModuleInterface] = [
      UserModule(),
      AuthModule(),
      FrontendModule(),
      RulesGenerationModule(),
      CacheAdminModule(),
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

  func setupServices() throws {
    // ServiceRegistry setup (replaces old Vapor DI system completely)
    // Create a semaphore to block until async setup completes
    let semaphore = DispatchSemaphore(value: 0)
    var setupError: Error?
    
    Task {
      do {
        try await setupServiceRegistry()
      } catch {
        setupError = error
      }
      semaphore.signal()
    }
    
    semaphore.wait()
    
    if let error = setupError {
      throw error
    }
  }
}

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
    // Load .env file first if it exists
    let envPath = DirectoryConfiguration.detect().workingDirectory + ".env"
    if FileManager.default.fileExists(atPath: envPath) {
      logger.info("Loading environment variables from .env file")
      do {
        let envContent = try String(contentsOfFile: envPath, encoding: .utf8)
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
        logger.warning("Could not load .env file: \(error)")
      }
    } else {
      logger.info("No .env file found at \(envPath)")
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
      databases.use(.sqlite(.memory), as: .sqlite)
      return
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
    databases.use(.postgres(configuration: postgresConfig), as: .psql)
  }

  func setupJWT() throws {
    if environment != .testing {
      let security = try configuration.security
      jwt.signers.use(.hs256(key: security.jwtKey))
    }
  }

  func setupServices() throws {
    // Existing Vapor DI setup (keeping for backward compatibility)
    repositories.usersService.use { app in DatabaseUserRepository(database: app.db) }
    repositories.emailTokensService.use { app in DatabaseEmailTokenRepository(database: app.db) }
    repositories.refreshTokensService.use { app in DatabaseRefreshTokenRepository(database: app.db)
    }
    repositories.passwordTokensService.use { app in
      DatabasePasswordTokenRepository(database: app.db)
    }

    // ServiceRegistry setup (replaces old Vapor DI system)
    Task {
      try await setupServiceRegistry()
    }
  }
}

import FluentPostgresDriver
import FluentSQLiteDriver
@preconcurrency import JWT
import Vapor

private extension String {
    var bytes: [UInt8] { .init(self.utf8) }
}

private extension JWKIdentifier {
    static let `public` = JWKIdentifier(string: "public")
    static let `private` = JWKIdentifier(string: "private")
}

extension Application {
    func setupConfiguration() throws {
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
                .accessControlRequestHeaders
            ]
        )
        middleware.use(CORSMiddleware(configuration: corsConfiguration))
        
        // Rate Limiting
        middleware.use(RateLimitMiddleware(
            maxRequests: security.rateLimitMaxRequests,
            windowMinutes: security.rateLimitWindowMinutes
        ))
        
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
        repositories.usersService.use { app in DatabaseUserRepository(database: app.db) }
        repositories.emailTokensService.use { app in DatabaseEmailTokenRepository(database: app.db) }
        repositories.refreshTokensService.use { app in DatabaseRefreshTokenRepository(database: app.db) }
        repositories.passwordTokensService.use { app in DatabasePasswordTokenRepository(database: app.db) }
        
        services.email.use(.brevo)
        services.randomGenerator.use(.random)
        services.uuidGenerator.use(.random)
        services.llm.use(.openAI)
        
        // Setup AI cache service
        try setupAICache()
    }
}

import Vapor

/// Protocol defining the interface for environment-specific configuration management.
///
/// This service provides a unified interface for accessing configuration values across
/// different deployment environments (development, testing, production, staging).
/// Each configuration implementation handles environment-specific settings and validation.
///
/// ## Usage
/// 
/// Configuration services are automatically initialized during application setup:
/// ```swift
/// let config = try app.configuration
/// let databaseConfig = try config.database
/// ```
///
/// ## Environment-Specific Implementations
///
/// - ``DevelopmentConfiguration``: Local development with SQLite and relaxed security
/// - ``TestingConfiguration``: Unit testing with in-memory databases and mock services  
/// - ``ProductionConfiguration``: Production deployment with PostgreSQL and strict security
///
/// ## Thread Safety
/// All configuration implementations conform to `Sendable` and are safe for concurrent access.
protocol ConfigurationService: Sendable {
    
    /// Database connection configuration for the current environment.
    ///
    /// - Returns: Database configuration containing host, credentials, and connection settings
    /// - Throws: ``ConfigurationError`` if required environment variables are missing or invalid
    var database: DatabaseConfig { get throws }
    
    /// External service configuration including API keys and endpoints.
    ///
    /// Contains configuration for:
    /// - OpenAI API integration
    /// - Brevo email service
    /// - Other third-party services
    ///
    /// - Returns: Services configuration with API keys and endpoints
    /// - Throws: ``ConfigurationError`` if service credentials are missing or invalid
    var services: ServicesConfig { get throws }
    
    /// Security configuration including JWT settings and CORS policies.
    ///
    /// Manages critical security settings:
    /// - JWT signing keys and expiration times
    /// - CORS allowed origins and headers
    /// - Rate limiting thresholds
    /// - App Attest validation settings
    ///
    /// - Returns: Security configuration for authentication and protection
    /// - Throws: ``ConfigurationError`` if security settings are invalid or missing
    var security: SecurityConfig { get throws }
    
    /// AWS service configuration for cloud integrations.
    ///
    /// - Returns: AWS configuration including credentials and region settings
    /// - Throws: ``ConfigurationError`` if AWS credentials are missing or invalid
    var aws: AWSConfig { get throws }
    
    /// Apple Push Notification Service configuration.
    ///
    /// - Returns: APNS configuration including certificates and environment settings
    /// - Throws: ``ConfigurationError`` if APNS configuration is invalid
    var apns: APNSConfig { get throws }
    
    /// AI response caching configuration and performance settings.
    ///
    /// Controls caching behavior for:
    /// - Rules generation responses (TTL: 24 hours)
    /// - Image analysis results (TTL: 7 days)
    /// - Cache size limits and eviction policies
    ///
    /// - Returns: Cache configuration with TTL settings and limits
    /// - Throws: ``ConfigurationError`` if cache settings are invalid
    var cache: CacheConfig { get throws }
    
    /// The current deployment environment.
    ///
    /// Used to determine which configuration implementation to use and
    /// adjust behavior based on environment (e.g., logging levels, security strictness).
    var environment: Environment { get }
    
    /// Validates all configuration settings for the current environment.
    ///
    /// Performs comprehensive validation of:
    /// - Required environment variables are present and valid
    /// - Database connection settings are correct
    /// - API keys and credentials are properly formatted
    /// - Security settings meet minimum requirements
    ///
    /// This method is called automatically during application startup to ensure
    /// the application doesn't start with invalid configuration.
    ///
    /// - Throws: ``ConfigurationError`` with detailed information about validation failures
    func validate() throws
}

/// Factory for creating environment-specific configuration instances.
///
/// This factory encapsulates the logic for selecting the appropriate configuration
/// implementation based on the current deployment environment. It ensures that
/// each environment gets its own specialized configuration with appropriate
/// defaults and validation rules.
///
/// ## Configuration Selection Logic
///
/// - `.development`: Uses ``DevelopmentConfiguration`` with SQLite and relaxed settings
/// - `.testing`: Uses ``TestingConfiguration`` with in-memory databases
/// - `.production`, `.staging`: Uses ``ProductionConfiguration`` with PostgreSQL and strict security
/// - Other environments: Defaults to ``ProductionConfiguration`` for safety
///
/// ## Usage
///
/// The factory is used internally during application initialization:
/// ```swift
/// let config = ConfigurationFactory.create(for: app.environment)
/// ```
struct ConfigurationFactory {
    
    /// Creates the appropriate configuration service for the specified environment.
    ///
    /// This method selects and instantiates the correct configuration implementation
    /// based on the deployment environment. Each environment gets specialized
    /// configuration that matches its operational requirements.
    ///
    /// - Parameter environment: The target deployment environment
    /// - Returns: A configuration service instance optimized for the specified environment
    ///
    /// ## Environment Mapping
    ///
    /// - `.development` → ``DevelopmentConfiguration``
    /// - `.testing` → ``TestingConfiguration``  
    /// - `.production`, `.staging` → ``ProductionConfiguration``
    /// - Unknown environments → ``ProductionConfiguration`` (fail-safe)
    static func create(for environment: Environment) -> ConfigurationService {
        switch environment {
        case .development:
            return DevelopmentConfiguration(environment: environment)
        case .testing:
            return TestingConfiguration(environment: environment)
        case .production, .staging:
            return ProductionConfiguration(environment: environment)
        default:
            return ProductionConfiguration(environment: environment)
        }
    }
}


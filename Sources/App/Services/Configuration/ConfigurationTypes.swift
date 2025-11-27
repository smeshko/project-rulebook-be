import Vapor

/// Database connection configuration for different deployment environments.
///
/// This configuration struct contains all necessary information to establish
/// a database connection, supporting both SQLite (development/testing) and
/// PostgreSQL (staging/production) deployments.
///
/// ## Usage
/// 
/// ```swift
/// let dbConfig = try app.configuration.database
/// let postgresConfig = SQLPostgresConfiguration(
///     hostname: dbConfig.host,
///     port: dbConfig.port,
///     username: dbConfig.username,
///     password: dbConfig.password,
///     database: dbConfig.name
/// )
/// ```
struct DatabaseConfig: Sendable {
    /// The name of the database to connect to.
    let name: String
    
    /// The hostname or IP address of the database server.
    let host: String
    
    /// The username for database authentication.
    let username: String
    
    /// The password for database authentication.
    let password: String
    
    /// The port number for the database connection (typically 5432 for PostgreSQL).
    let port: Int
}

/// Configuration for external service integrations and API keys.
///
/// This struct centralizes all third-party service credentials and endpoints,
/// ensuring secure and consistent access to external services across the application.
///
/// ## Security Note
/// All API keys should be stored as environment variables and never hard-coded.
/// The configuration service validates that all required keys are present at startup.
struct ServicesConfig: Sendable {
    /// API key for Brevo email service integration.
    ///
    /// Used for sending transactional emails including:
    /// - Email verification messages
    /// - Password reset notifications
    /// - User account notifications
    let brevoAPIKey: String
    
    /// Base URL for Brevo API endpoints.
    ///
    /// Typically `https://api.brevo.com/v3` for production.
    let brevoURL: String
    
    /// API key for OpenAI service integration.
    ///
    /// Required for AI-powered features:
    /// - Game rules generation
    /// - Board game box image analysis
    /// - Content validation and processing
    ///
    /// ## Important
    /// This key provides access to OpenAI's `/v1/responses` endpoint (not Chat Completions).
    let openAIKey: String

    /// API key for Google Gemini service integration.
    ///
    /// Required for AI-powered features using Google's Gemini models:
    /// - Game rules generation
    /// - Board game box image analysis
    /// - Content validation and processing
    let geminiApiKey: String
}

/// Security configuration including authentication, CORS, and rate limiting settings.
///
/// This configuration manages all security-related settings that protect the application
/// from various attacks and ensure proper authentication and authorization.
///
/// ## Security Features Configured
/// - JWT token signing and validation
/// - CORS policy enforcement
/// - Rate limiting thresholds
/// - App Store attestation validation
struct SecurityConfig: Sendable {
    /// The base URL of the application for security validations.
    ///
    /// Used for:
    /// - CORS origin validation
    /// - JWT audience claims
    /// - Redirect URL validation
    let baseURL: String
    
    /// The App Store application identifier for App Attest validation.
    ///
    /// This identifier is used to validate that requests are coming from
    /// the legitimate iOS application and not from malicious sources.
    let appIdentifier: String
    
    /// The secret key used for JWT token signing and verification.
    ///
    /// ## Security Requirements
    /// - Must be at least 256 bits (32 characters) for HMAC-SHA256
    /// - Should be cryptographically random
    /// - Must be kept secret and rotated regularly
    /// - Different keys should be used for different environments
    let jwtKey: String
    
    /// List of allowed CORS origins for cross-origin requests.
    ///
    /// Controls which domains can make requests to the API from browsers.
    /// Should be restrictive in production environments.
    ///
    /// ## Example
    /// ```swift
    /// corsAllowedOrigins: ["https://yourapp.com", "https://admin.yourapp.com"]
    /// ```
    let corsAllowedOrigins: [String]
    
    /// Maximum number of requests allowed within the rate limit window.
    ///
    /// This is a legacy configuration property. The new rate limiting system
    /// uses operation-specific limits defined in ``RateLimitConfiguration``.
    let rateLimitMaxRequests: Int
    
    /// Rate limit window duration in minutes.
    ///
    /// This is a legacy configuration property. The new rate limiting system
    /// uses operation-specific windows defined in ``RateLimitConfiguration``.
    let rateLimitWindowMinutes: Int
}

/// AWS service configuration for cloud integrations.
///
/// Contains credentials and configuration for AWS services used by the application,
/// including S3 for file storage and other AWS integrations.
///
/// ## Security Note
/// AWS credentials should be managed through IAM roles in production environments
/// rather than static access keys when possible.
struct AWSConfig: Sendable {
    /// AWS access key ID for API authentication.
    let accessKey: String
    
    /// AWS secret access key for API authentication.
    ///
    /// ## Security Warning
    /// This credential provides broad access to AWS services. Ensure it's:
    /// - Stored securely as an environment variable
    /// - Associated with an IAM user/role with minimal required permissions
    /// - Rotated regularly
    let secretAccessKey: String
    
    /// AWS region for service endpoints (e.g., "us-east-1", "eu-west-1").
    let region: String
    
    /// S3 bucket name for file storage operations.
    let s3BucketName: String
}

/// Apple Push Notification Service configuration.
///
/// Configuration for sending push notifications to iOS devices through APNS.
/// Requires proper certificates and team configuration from Apple Developer Portal.
struct APNSConfig: Sendable {
    /// APNS authentication key identifier from Apple Developer Portal.
    let key: String
    
    /// Private key content for APNS authentication.
    ///
    /// This should be the content of the .p8 private key file downloaded
    /// from Apple Developer Portal, stored as an environment variable.
    let privateKey: String
    
    /// Apple Developer Team ID for APNS authentication.
    let teamId: String
}

/// AI response caching configuration and performance optimization settings.
///
/// This configuration controls the caching behavior for AI-generated responses,
/// which is critical for performance and cost optimization by reducing redundant
/// API calls to external AI services.
///
/// ## Performance Benefits
/// - Reduces OpenAI API costs through intelligent caching
/// - Improves response times for repeated queries
/// - Enables offline-like performance for cached content
struct CacheConfig: Sendable {
    /// Maximum number of cache entries before eviction begins.
    ///
    /// When this limit is reached, the cache uses an LRU (Least Recently Used)
    /// eviction policy to remove older entries and make room for new ones.
    let maxEntries: Int

    /// Time-to-live for rules generation responses in seconds.
    ///
    /// Default: 86400 seconds (24 hours)
    ///
    /// Rules generation results are cached for 24 hours since game rules
    /// are relatively stable and don't change frequently.
    let rulesGenerationTTL: TimeInterval

    /// Interval between automatic cache cleanup operations in seconds.
    ///
    /// The cache automatically removes expired entries at this interval
    /// to prevent memory bloat and maintain optimal performance.
    let cleanupInterval: TimeInterval

    /// Whether to enable detailed cache operation logging.
    ///
    /// When enabled, logs cache hits, misses, and performance metrics.
    /// Should typically be enabled in development and disabled in production
    /// to avoid log noise.
    let enableLogging: Bool
}

/// Redis cache configuration for high-performance distributed caching.
///
/// This configuration defines connection parameters and behavior for Redis,
/// which provides persistent, distributed caching capabilities that scale
/// beyond in-memory caching limitations.
///
/// ## Use Cases
/// - LLM response caching across multiple server instances
/// - Session storage for user authentication
/// - Rate limiting counters and statistics
/// - Real-time data caching for improved performance
public struct RedisConfig: Sendable {
    /// Redis server hostname or IP address.
    public let host: String
    
    /// Redis server port number (default: 6379).
    public let port: Int
    
    /// Optional password for Redis authentication.
    public let password: String?
    
    /// Redis database number to use (0-15, default: 0).
    public let database: Int
    
    /// Maximum number of connections in the connection pool.
    ///
    /// Higher values allow better concurrency but consume more resources.
    /// Recommended: 10-20 for most applications.
    public let poolSize: Int
    
    /// Connection timeout in seconds.
    ///
    /// Time to wait for a connection to be established before failing.
    public let connectionTimeout: TimeInterval
    
    /// Command timeout in seconds.
    ///
    /// Maximum time to wait for a Redis command to complete.
    public let commandTimeout: TimeInterval
    
    /// Whether to enable Redis operation logging.
    ///
    /// When enabled, logs Redis commands, performance metrics, and errors.
    /// Useful for debugging and performance monitoring.
    public let enableLogging: Bool
}

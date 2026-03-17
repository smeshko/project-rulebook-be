import Foundation

/// Enumeration of rate limit categories with different protection levels.
///
/// This enum defines the different types of operations that can be rate limited,
/// each with its own specific limits and characteristics. The categories are
/// ordered from most restrictive to most lenient.
///
/// ## Rate Limiting Hierarchy
///
/// The categories are designed with a clear hierarchy based on:
/// - **Resource Cost**: More expensive operations have stricter limits
/// - **Security Risk**: Security-sensitive operations require tighter controls
/// - **User Impact**: Balance between protection and user experience
/// - **Business Priority**: Critical functions get appropriate resource allocation
///
/// ## Usage in Headers
/// The raw values are used in HTTP response headers (`X-RateLimit-Type`)
/// to inform clients about which type of rate limiting was applied.
enum RateLimitType: String, CaseIterable {
    
    /// Image analysis operations using AI vision APIs.
    ///
    /// **Most Restrictive Category**
    ///
    /// Applied to board game box image recognition and analysis endpoints.
    /// These operations are the most expensive due to:
    /// - High OpenAI API costs for vision models
    /// - Computational complexity of image processing
    /// - Potential for abuse through large image uploads
    ///
    /// **Typical Limits**: 3-50 requests per hour depending on environment
    case imageAnalysis = "image_analysis"
    
    /// Rules generation operations using AI text models.
    ///
    /// **Very Restrictive Category**
    ///
    /// Applied to game rules generation endpoints that create detailed
    /// rule explanations using AI text generation. Costs are significant but
    /// lower than image analysis.
    ///
    /// **Typical Limits**: 5-100 requests per hour depending on environment
    case rulesGeneration = "rules_generation"
    
    /// Administrative operations requiring elevated privileges.
    ///
    /// **Restrictive Category**
    ///
    /// Applied to admin-only endpoints including:
    /// - Cache management and statistics
    /// - System configuration changes
    /// - User management operations
    /// - Performance monitoring endpoints
    ///
    /// **Typical Limits**: 10-200 requests per 5 minutes depending on environment
    case admin = "admin"
    
    /// General API operations for standard application functionality.
    ///
    /// **Moderate Category**
    ///
    /// Applied to standard API endpoints including:
    /// - User authentication and profile management
    /// - CRUD operations for application data
    /// - Standard business logic endpoints
    ///
    /// **Typical Limits**: 50-1000 requests per hour depending on environment
    case api = "api"
    
    /// General web requests including static content and pages.
    ///
    /// **Lenient Category**
    ///
    /// Applied to low-cost operations including:
    /// - Static file serving (CSS, images, etc.)
    /// - Web page requests
    /// - Health checks and monitoring endpoints
    ///
    /// **Typical Limits**: 500-10,000 requests per hour depending on environment
    case general = "general"

    /// Waitlist subscription operations for the public signup endpoint.
    ///
    /// **Restrictive Category**
    ///
    /// Applied to waitlist endpoints including:
    /// - Email subscription signup
    /// - Unsubscribe requests
    ///
    /// This protects against automated spam while allowing legitimate signups.
    ///
    /// **Typical Limits**: 10 requests per hour
    case waitlist = "waitlist"

    /// Receipt validation operations for in-app purchase verification.
    ///
    /// **Restrictive Category**
    ///
    /// Applied to receipt validation endpoints to throttle abuse and
    /// brute-force attempts against the purchase verification system.
    ///
    /// **Typical Limits**: 30 requests per hour per IP
    case receipt = "receipt"
}

/// Container for rate limit information specific to an operation type.
///
/// This struct encapsulates all the information needed to enforce rate limiting
/// for a specific request, including the category, limits, and time window.
///
/// ## Usage
///
/// Created by ``RateLimitMiddleware.determineRateLimit(for:)`` to specify
/// the rate limiting rules that should be applied to a particular request.
///
/// ## Properties
///
/// The struct contains all information needed for:
/// - Enforcement of rate limits
/// - HTTP header generation
/// - Logging and monitoring
/// - Client notification of limits
struct RateLimitInfo {
    
    /// The category of rate limiting being applied.
    ///
    /// Determines which set of limits and time windows are used,
    /// and appears in HTTP response headers for client awareness.
    let type: RateLimitType
    
    /// Maximum number of requests allowed within the time window.
    ///
    /// When this limit is reached, subsequent requests will be
    /// rejected with HTTP 429 (Too Many Requests) until the
    /// time window resets.
    let maxRequests: Int
    
    /// Duration of the rate limiting window in seconds.
    ///
    /// Rate limits are calculated using a sliding window of this
    /// duration. Common values:
    /// - 300 seconds (5 minutes) for admin operations
    /// - 3600 seconds (1 hour) for AI and API operations
    let windowSeconds: Int
}
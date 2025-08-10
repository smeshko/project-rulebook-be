import Foundation

/// Configuration for operation-specific rate limiting with tiered protection levels.
///
/// This configuration implements a sophisticated rate limiting strategy that applies
/// different limits based on the type and cost of operations, providing optimal
/// protection while maintaining good user experience.
///
/// ## Rate Limiting Strategy
/// 
/// The system uses a **tiered approach** with increasingly restrictive limits based on:
/// - **Resource Cost**: AI operations consume external API credits
/// - **Security Risk**: Admin operations require stricter controls
/// - **User Impact**: Balance between protection and usability
/// - **Business Logic**: Different limits for different application areas
///
/// ## Tier Structure
/// 
/// 1. **AI Operations** (Most Restrictive)
///    - Image analysis and rules generation
///    - High cost operations using external AI APIs
///    - Strict limits to prevent abuse and cost overruns
///
/// 2. **Admin Operations** (Restricted)
///    - Administrative endpoints and cache management
///    - Security-sensitive operations requiring careful access control
///    - Moderate limits balancing security with administrative needs
///
/// 3. **API Operations** (Moderate)
///    - General API endpoints for application functionality
///    - Standard business operations with reasonable resource usage
///    - Balanced limits supporting normal application usage
///
/// 4. **General Operations** (Lenient)  
///    - Web page requests and static content
///    - Low-cost operations with minimal security impact
///    - Generous limits supporting good user experience
///
/// ## Environment-Specific Configurations
/// 
/// - **Production**: Conservative limits optimized for cost control and security
/// - **Development**: Relaxed limits supporting development and testing workflows
/// - **Default**: Balanced limits suitable for most deployment scenarios
struct RateLimitConfiguration {
    
    // MARK: - AI Operation Limits (Tier 1 - Most Restrictive)
    
    /// Maximum number of image analysis requests allowed within the time window.
    ///
    /// Image analysis operations are the most expensive, using OpenAI's vision API
    /// which has higher per-request costs than text generation.
    ///
    /// **Production**: 3 requests/hour (very conservative)
    /// **Development**: 50 requests/hour (testing-friendly)
    let imageAnalysisLimit: Int
    
    /// Time window for image analysis rate limiting in seconds.
    ///
    /// Uses 1-hour windows to provide reasonable daily allowances while
    /// preventing burst usage that could exhaust API quotas.
    let imageAnalysisWindow: Int
    
    /// Maximum number of rules generation requests allowed within the time window.
    ///
    /// Rules generation uses text-based AI models which are less expensive than
    /// vision models but still consume significant API credits.
    ///
    /// **Production**: 5 requests/hour
    /// **Development**: 100 requests/hour
    let rulesGenerationLimit: Int
    
    /// Time window for rules generation rate limiting in seconds.
    let rulesGenerationWindow: Int
    
    // MARK: - Admin Operation Limits (Tier 2 - Restricted)
    
    /// Maximum number of admin requests allowed within the time window.
    ///
    /// Administrative operations require elevated privileges and could impact
    /// system state, requiring careful rate limiting for security.
    ///
    /// **Production**: 10 requests/5 minutes
    /// **Development**: 200 requests/5 minutes
    let adminLimit: Int
    
    /// Time window for admin rate limiting in seconds.
    ///
    /// Uses shorter 5-minute windows for admin operations to quickly throttle
    /// potential abuse while allowing legitimate administrative tasks.
    let adminWindow: Int
    
    // MARK: - API Operation Limits (Tier 3 - Moderate)
    
    /// Maximum number of general API requests allowed within the time window.
    ///
    /// Covers standard application API endpoints including user management,
    /// authentication, and basic CRUD operations.
    ///
    /// **Production**: 50 requests/hour
    /// **Development**: 1000 requests/hour
    let apiLimit: Int
    
    /// Time window for API rate limiting in seconds.
    let apiWindow: Int
    
    // MARK: - General Operation Limits (Tier 4 - Lenient)
    
    /// Maximum number of general web requests allowed within the time window.
    ///
    /// Applies to static content, web pages, and other low-cost operations
    /// that don't consume significant server resources.
    ///
    /// **Production**: 500 requests/hour
    /// **Development**: 10,000 requests/hour
    let generalLimit: Int
    
    /// Time window for general request rate limiting in seconds.
    let generalWindow: Int
    
    /// Default rate limiting configuration suitable for most deployments.
    ///
    /// Provides balanced limits that protect against abuse while supporting
    /// normal application usage patterns. This configuration is recommended
    /// for staging environments and initial production deployments.
    ///
    /// ## Limit Summary
    /// - **Image Analysis**: 5 requests/hour (moderate protection)
    /// - **Rules Generation**: 10 requests/hour (reasonable for typical usage)
    /// - **Admin Operations**: 20 requests/5 minutes (administrative flexibility)
    /// - **API Operations**: 100 requests/hour (supports active usage)
    /// - **General Requests**: 1000 requests/hour (generous for web browsing)
    static let `default` = RateLimitConfiguration(
        // AI operations: Very restrictive to prevent abuse
        imageAnalysisLimit: 5,
        imageAnalysisWindow: 3600, // 1 hour
        rulesGenerationLimit: 10,
        rulesGenerationWindow: 3600, // 1 hour
        
        // Admin operations: Restricted but reasonable
        adminLimit: 20,
        adminWindow: 300, // 5 minutes
        
        // API operations: Moderate limits
        apiLimit: 100,
        apiWindow: 3600, // 1 hour
        
        // General web requests: Lenient
        generalLimit: 1000,
        generalWindow: 3600 // 1 hour
    )
    
    /// Production rate limiting configuration optimized for cost control and security.
    ///
    /// Implements conservative limits designed for production environments where
    /// cost control, security, and stability are paramount. These limits prevent
    /// abuse while maintaining acceptable service for legitimate users.
    ///
    /// ## Production Optimizations
    /// - **Cost Control**: Strict AI operation limits prevent unexpected API costs
    /// - **Security Focus**: Restrictive admin limits reduce attack surface
    /// - **Stability**: Conservative limits ensure consistent performance
    /// - **Abuse Prevention**: Low limits make abuse economically unviable
    ///
    /// ## Limit Summary
    /// - **Image Analysis**: 3 requests/hour (very conservative)
    /// - **Rules Generation**: 5 requests/hour (cost-controlled)
    /// - **Admin Operations**: 10 requests/5 minutes (security-focused)
    /// - **API Operations**: 50 requests/hour (reasonable for production)
    /// - **General Requests**: 500 requests/hour (adequate for web usage)
    ///
    /// - Returns: Configuration optimized for production deployment
    static func production() -> RateLimitConfiguration {
        return RateLimitConfiguration(
            imageAnalysisLimit: 3,
            imageAnalysisWindow: 3600,
            rulesGenerationLimit: 5,
            rulesGenerationWindow: 3600,
            adminLimit: 10,
            adminWindow: 300,
            apiLimit: 50,
            apiWindow: 3600,
            generalLimit: 500,
            generalWindow: 3600
        )
    }
    
    /// Development rate limiting configuration with relaxed limits for testing.
    ///
    /// Provides generous limits suitable for development and testing environments
    /// where developers need flexibility to iterate quickly and test various
    /// scenarios without hitting rate limits.
    ///
    /// ## Development Features
    /// - **Testing Flexibility**: High limits support extensive testing
    /// - **Developer Productivity**: Minimal throttling during development
    /// - **API Exploration**: Generous allowances for experimenting with features
    /// - **Load Testing**: Sufficient capacity for performance testing
    ///
    /// ## Limit Summary
    /// - **Image Analysis**: 50 requests/hour (testing-friendly)
    /// - **Rules Generation**: 100 requests/hour (extensive testing support)
    /// - **Admin Operations**: 200 requests/5 minutes (development flexibility)
    /// - **API Operations**: 1000 requests/hour (ample for development)
    /// - **General Requests**: 10,000 requests/hour (no practical limit)
    ///
    /// - Returns: Configuration optimized for development and testing
    static func development() -> RateLimitConfiguration {
        return RateLimitConfiguration(
            imageAnalysisLimit: 50,
            imageAnalysisWindow: 3600,
            rulesGenerationLimit: 100,
            rulesGenerationWindow: 3600,
            adminLimit: 200,
            adminWindow: 300,
            apiLimit: 1000,
            apiWindow: 3600,
            generalLimit: 10000,
            generalWindow: 3600
        )
    }
}
import Vapor

struct ProductionConfiguration: ConfigurationService {
    let environment: Environment
    
    var database: DatabaseConfig {
        get throws {
            guard let name = Environment.get("DATABASE_NAME") else {
                throw ConfigurationError.missingRequired(
                    key: "DATABASE_NAME",
                    suggestion: "Set DATABASE_NAME environment variable for production database"
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
                  let port = Int(portString) else {
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
            
            return ServicesConfig(
                brevoAPIKey: brevoAPIKey,
                brevoURL: Environment.get("BREVO_URL") ?? "https://api.brevo.com",
                openAIKey: openAIKey
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
            
            return SecurityConfig(
                baseURL: baseURL,
                appIdentifier: appIdentifier,
                jwtKey: jwtKey
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
    
    func validate() throws {
        let db = try database
        let services = try services
        let security = try security
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
    }
}
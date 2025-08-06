import Vapor

struct DevelopmentConfiguration: ConfigurationService {
    let environment: Environment
    
    var database: DatabaseConfig {
        get throws {
            DatabaseConfig(
                name: Environment.get("DATABASE_NAME") ?? "dev_database",
                host: Environment.get("DATABASE_HOST") ?? "localhost",
                username: Environment.get("DATABASE_USERNAME") ?? "dev_user",
                password: Environment.get("DATABASE_PASSWORD") ?? "dev_password",
                port: Int(Environment.get("DATABASE_PORT") ?? "5432") ?? 5432
            )
        }
    }
    
    var services: ServicesConfig {
        get throws {
            ServicesConfig(
                brevoAPIKey: Environment.get("BREVO_API_KEY") ?? "dev_brevo_key",
                brevoURL: Environment.get("BREVO_URL") ?? "https://api.brevo.com",
                openAIKey: Environment.get("OPENAI_KEY") ?? "dev_openai_key"
            )
        }
    }
    
    var security: SecurityConfig {
        get throws {
            SecurityConfig(
                baseURL: Environment.get("BASE_URL") ?? "http://localhost:8080",
                appIdentifier: Environment.get("APPLICATION_IDENTIFIER") ?? "com.dev.app",
                jwtKey: Environment.get("JWT_KEY") ?? "development_jwt_key_32_chars_min"
            )
        }
    }
    
    var aws: AWSConfig {
        get throws {
            AWSConfig(
                accessKey: Environment.get("AWS_ACCESS_KEY") ?? "dev_access_key",
                secretAccessKey: Environment.get("AWS_SECRET_ACCESS_KEY") ?? "dev_secret_key",
                region: Environment.get("AWS_REGION") ?? "us-west-2",
                s3BucketName: Environment.get("AWS_S3_BUCKET_NAME") ?? "dev-bucket"
            )
        }
    }
    
    var apns: APNSConfig {
        get throws {
            APNSConfig(
                key: Environment.get("APNS_KEY") ?? "dev_apns_key",
                privateKey: Environment.get("APNS_PRIVATE_KEY") ?? "dev_private_key",
                teamId: Environment.get("APNS_TEAM_ID") ?? "DEV_TEAM_ID"
            )
        }
    }
    
    func validate() throws {
        let db = try database
        
        // Minimal validation for development
        if db.port < 1 || db.port > 65535 {
            throw ConfigurationError.invalidFormat(
                key: "DATABASE_PORT", 
                expected: "1-65535", 
                got: "\(db.port)"
            )
        }
        
        let sec = try security
        if sec.jwtKey.count < 16 {
            throw ConfigurationError.validationFailed(
                component: "JWT",
                reason: "JWT key should be at least 16 characters for development"
            )
        }
    }
}
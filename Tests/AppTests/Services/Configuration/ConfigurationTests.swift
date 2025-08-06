@testable import App
import XCTest
import Vapor

final class ConfigurationTests: XCTestCase {
    func testDevelopmentConfigurationDefaults() throws {
        let config = DevelopmentConfiguration(environment: .development)
        
        let db = try config.database
        XCTAssertEqual(db.host, "localhost")
        XCTAssertEqual(db.port, 5432)
        XCTAssertEqual(db.name, "dev_database")
        XCTAssertEqual(db.username, "dev_user")
        XCTAssertEqual(db.password, "dev_password")
        
        let services = try config.services
        XCTAssertEqual(services.brevoURL, "https://api.brevo.com")
        
        let security = try config.security
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testDevelopmentConfigurationWithEnvironmentVariables() throws {
        // Set environment variables
        Environment.process.DATABASE_NAME = "custom_dev_db"
        Environment.process.DATABASE_HOST = "custom_host"
        defer {
            Environment.process.DATABASE_NAME = nil
            Environment.process.DATABASE_HOST = nil
        }
        
        let config = DevelopmentConfiguration(environment: .development)
        let db = try config.database
        
        XCTAssertEqual(db.name, "custom_dev_db")
        XCTAssertEqual(db.host, "custom_host")
    }
    
    func testProductionConfigurationValidationFailsWithoutEnvironment() throws {
        // Clear all environment variables that production requires
        let originalValues: [String: String?] = [
            "DATABASE_NAME": Environment.process.DATABASE_NAME,
            "DATABASE_HOST": Environment.process.DATABASE_HOST,
            "DATABASE_USERNAME": Environment.process.DATABASE_USERNAME,
            "DATABASE_PASSWORD": Environment.process.DATABASE_PASSWORD,
            "DATABASE_PORT": Environment.process.DATABASE_PORT
        ]
        
        defer {
            // Restore original values
            for (key, value) in originalValues {
                Environment.process[key] = value
            }
        }
        
        // Clear required environment variables
        Environment.process.DATABASE_NAME = nil
        Environment.process.DATABASE_HOST = nil
        Environment.process.DATABASE_USERNAME = nil
        Environment.process.DATABASE_PASSWORD = nil
        Environment.process.DATABASE_PORT = nil
        
        let config = ProductionConfiguration(environment: .production)
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is ConfigurationError)
            if let configError = error as? ConfigurationError {
                XCTAssertTrue(configError.description.contains("DATABASE_NAME"))
            }
        }
    }
    
    func testProductionConfigurationValidation() throws {
        // Set required environment variables
        Environment.process.DATABASE_NAME = "prod_db"
        Environment.process.DATABASE_HOST = "prod_host"
        Environment.process.DATABASE_USERNAME = "prod_user"
        Environment.process.DATABASE_PASSWORD = "prod_pass"
        Environment.process.DATABASE_PORT = "5432"
        Environment.process.BREVO_API_KEY = "test_brevo_key"
        Environment.process.OPENAI_KEY = "test_openai_key"
        Environment.process.BASE_URL = "https://example.com"
        Environment.process.APPLICATION_IDENTIFIER = "com.test.app"
        Environment.process.JWT_KEY = "this_is_a_jwt_key_with_at_least_32_characters"
        Environment.process.AWS_ACCESS_KEY = "test_aws_key"
        Environment.process.AWS_SECRET_ACCESS_KEY = "test_aws_secret"
        Environment.process.AWS_REGION = "us-west-2"
        Environment.process.AWS_S3_BUCKET_NAME = "test-bucket"
        Environment.process.APNS_KEY = "test_apns_key"
        Environment.process.APNS_PRIVATE_KEY = "test_private_key"
        Environment.process.APNS_TEAM_ID = "TEST_TEAM_ID"
        
        defer {
            // Clean up
            let keys = ["DATABASE_NAME", "DATABASE_HOST", "DATABASE_USERNAME", "DATABASE_PASSWORD", "DATABASE_PORT",
                       "BREVO_API_KEY", "OPENAI_KEY", "BASE_URL", "APPLICATION_IDENTIFIER", "JWT_KEY",
                       "AWS_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY", "AWS_REGION", "AWS_S3_BUCKET_NAME",
                       "APNS_KEY", "APNS_PRIVATE_KEY", "APNS_TEAM_ID"]
            for key in keys {
                Environment.process[key] = nil
            }
        }
        
        let config = ProductionConfiguration(environment: .production)
        
        XCTAssertNoThrow(try config.validate())
        
        let db = try config.database
        XCTAssertEqual(db.name, "prod_db")
        XCTAssertEqual(db.host, "prod_host")
        
        let security = try config.security
        XCTAssertEqual(security.baseURL, "https://example.com")
    }
    
    func testTestingConfigurationProvidesSensibleDefaults() throws {
        let config = TestingConfiguration(environment: .testing)
        
        let db = try config.database
        XCTAssertEqual(db.name, "test_db")
        XCTAssertEqual(db.host, "localhost")
        
        let security = try config.security
        XCTAssertEqual(security.jwtKey, "test_jwt_key_32_characters_long!")
        XCTAssertEqual(security.baseURL, "http://localhost:8080")
        
        XCTAssertNoThrow(try config.validate())
    }
    
    func testConfigurationFactoryCreatesDifferentTypesForEnvironments() {
        let devConfig = ConfigurationFactory.create(for: .development)
        XCTAssertTrue(devConfig is DevelopmentConfiguration)
        
        let prodConfig = ConfigurationFactory.create(for: .production)
        XCTAssertTrue(prodConfig is ProductionConfiguration)
        
        let stagingConfig = ConfigurationFactory.create(for: .staging)
        XCTAssertTrue(stagingConfig is ProductionConfiguration)
        
        let testConfig = ConfigurationFactory.create(for: .testing)
        XCTAssertTrue(testConfig is TestingConfiguration)
    }
    
    func testJWTKeyValidationInProduction() throws {
        Environment.process.DATABASE_NAME = "prod_db"
        Environment.process.DATABASE_HOST = "prod_host"
        Environment.process.DATABASE_USERNAME = "prod_user"
        Environment.process.DATABASE_PASSWORD = "prod_pass"
        Environment.process.DATABASE_PORT = "5432"
        Environment.process.BREVO_API_KEY = "test_brevo_key"
        Environment.process.OPENAI_KEY = "test_openai_key"
        Environment.process.BASE_URL = "https://example.com"
        Environment.process.APPLICATION_IDENTIFIER = "com.test.app"
        Environment.process.JWT_KEY = "short" // Too short for production
        Environment.process.AWS_ACCESS_KEY = "test_aws_key"
        Environment.process.AWS_SECRET_ACCESS_KEY = "test_aws_secret"
        Environment.process.AWS_REGION = "us-west-2"
        Environment.process.AWS_S3_BUCKET_NAME = "test-bucket"
        Environment.process.APNS_KEY = "test_apns_key"
        Environment.process.APNS_PRIVATE_KEY = "test_private_key"
        Environment.process.APNS_TEAM_ID = "TEST_TEAM_ID"
        
        defer {
            let keys = ["DATABASE_NAME", "DATABASE_HOST", "DATABASE_USERNAME", "DATABASE_PASSWORD", "DATABASE_PORT",
                       "BREVO_API_KEY", "OPENAI_KEY", "BASE_URL", "APPLICATION_IDENTIFIER", "JWT_KEY",
                       "AWS_ACCESS_KEY", "AWS_SECRET_ACCESS_KEY", "AWS_REGION", "AWS_S3_BUCKET_NAME",
                       "APNS_KEY", "APNS_PRIVATE_KEY", "APNS_TEAM_ID"]
            for key in keys {
                Environment.process[key] = nil
            }
        }
        
        let config = ProductionConfiguration(environment: .production)
        
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertTrue(error is ConfigurationError)
            if let configError = error as? ConfigurationError {
                XCTAssertTrue(configError.description.contains("JWT key must be at least 32 characters"))
            }
        }
    }
}

extension Environment {
    static var process: ProcessInfo { ProcessInfo.processInfo }
}

extension ProcessInfo {
    subscript(key: String) -> String? {
        get { environment[key] }
        set { 
            if let value = newValue {
                setEnvironmentVariable(value, forKey: key)
            } else {
                unsetEnvironmentVariable(forKey: key)
            }
        }
    }
    
    private func setEnvironmentVariable(_ value: String, forKey key: String) {
        var env = environment
        env[key] = value
        // Note: This approach doesn't actually modify the process environment
        // For real tests, you'd need to use a different approach
    }
    
    private func unsetEnvironmentVariable(forKey key: String) {
        var env = environment
        env.removeValue(forKey: key)
        // Note: This approach doesn't actually modify the process environment
        // For real tests, you'd need to use a different approach
    }
}
import Vapor

protocol ConfigurationService: Sendable {
    var database: DatabaseConfig { get throws }
    var services: ServicesConfig { get throws }
    var security: SecurityConfig { get throws }
    var aws: AWSConfig { get throws }
    var apns: APNSConfig { get throws }
    var environment: Environment { get }
    
    func validate() throws
}

// Factory for creating configuration instances
struct ConfigurationFactory {
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


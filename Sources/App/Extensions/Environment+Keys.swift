import Vapor

extension Application {
    private struct ConfigurationKey: StorageKey {
        typealias Value = ConfigurationService
    }
    
    var configuration: ConfigurationService {
        get {
            guard let config = storage[ConfigurationKey.self] else {
                fatalError("Configuration not initialized. Call app.initializeConfiguration() first.")
            }
            return config
        }
        set {
            storage[ConfigurationKey.self] = newValue
        }
    }
    
    func initializeConfiguration() throws {
        let config = ConfigurationFactory.create(for: environment)
        try config.validate()
        self.configuration = config
    }
}

// MARK: - Legacy support extensions - use app.configuration directly instead
extension Environment {
    static var databaseName: String {
        fatalError("Use app.configuration.database.name instead of Environment.databaseName")
    }
    
    static var databaseHost: String {
        fatalError("Use app.configuration.database.host instead of Environment.databaseHost")
    }
    
    static var databaseUser: String {
        fatalError("Use app.configuration.database.username instead of Environment.databaseUser")
    }
    
    static var databasePassword: String {
        fatalError("Use app.configuration.database.password instead of Environment.databasePassword")
    }
    
    static var databasePort: Int {
        fatalError("Use app.configuration.database.port instead of Environment.databasePort")
    }
    
    static var mailProviderKey: String {
        fatalError("Use app.configuration.services.brevoAPIKey instead of Environment.mailProviderKey")
    }
    
    static var mailProviderUrl: String {
        fatalError("Use app.configuration.services.brevoURL instead of Environment.mailProviderUrl")
    }
    
    static var openAIKey: String {
        fatalError("Use app.configuration.services.openAIKey instead of Environment.openAIKey")
    }
    
    static var awsAccessKey: String {
        fatalError("Use app.configuration.aws.accessKey instead of Environment.awsAccessKey")
    }
    
    static var awsSecretAccessKey: String {
        fatalError("Use app.configuration.aws.secretAccessKey instead of Environment.awsSecretAccessKey")
    }
    
    static var awsRegion: String {
        fatalError("Use app.configuration.aws.region instead of Environment.awsRegion")
    }
    
    static var awsS3BucketName: String {
        fatalError("Use app.configuration.aws.s3BucketName instead of Environment.awsS3BucketName")
    }
    
    static var apnsKey: String {
        fatalError("Use app.configuration.apns.key instead of Environment.apnsKey")
    }
    
    static var apnsPrivateKey: String {
        fatalError("Use app.configuration.apns.privateKey instead of Environment.apnsPrivateKey")
    }
    
    static var apnsTeamId: String {
        fatalError("Use app.configuration.apns.teamId instead of Environment.apnsTeamId")
    }
    
    static var baseURL: String {
        fatalError("Use app.configuration.security.baseURL instead of Environment.baseURL")
    }
    
    static var appIdentifier: String {
        fatalError("Use app.configuration.security.appIdentifier instead of Environment.appIdentifier")
    }
    
    static var jwtKey: String {
        fatalError("Use app.configuration.security.jwtKey instead of Environment.jwtKey")
    }
}

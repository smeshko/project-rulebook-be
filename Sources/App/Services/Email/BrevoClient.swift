import Vapor

extension Application.Service.Provider where ServiceType == EmailService {
    static var brevo: Self {
        .init {
            $0.services.email.use { BrevoClient(app: $0) }
        }
    }
}

struct BrevoClient: EmailService {
    let app: Application
    
    func `for`(_ request: Request) -> any EmailService {
        Self.init(app: request.application)
    }
    
    @discardableResult
    func send(_ email: any Email) async throws -> HTTPStatus {
        let config = try app.configuration.services
        let response = try await app.client.post(
            URI(string: config.brevoURL),
            headers: .init([
                ("accept", "application/json"),
                ("api-key", config.brevoAPIKey),
                ("content-type", "application/json")
            ]),
            content: email
        )
        
        return response.status
    }
}

// MARK: - ServiceLifecycle Implementation

extension BrevoClient: ServiceLifecycle {
    /// Initializes the Brevo email service during application startup.
    func startup(_ app: Application) async throws {
        do {
            let config = try app.configuration.services
            
            // Validate configuration is present
            guard !config.brevoAPIKey.isEmpty else {
                throw ConfigurationError.missingRequired(key: "BREVO_API_KEY", suggestion: "Set the Brevo API key in environment variables")
            }
            
            guard !config.brevoURL.isEmpty else {
                throw ConfigurationError.missingRequired(key: "BREVO_URL", suggestion: "Set the Brevo API URL in environment variables")
            }
            
            
            // Test connectivity by attempting to get account information
            // This is a lightweight operation that verifies API key validity
            let response = try await app.client.get(
                URI(string: config.brevoURL + "/v3/account"),
                headers: .init([
                    ("accept", "application/json"),
                    ("api-key", config.brevoAPIKey)
                ])
            )
            
            guard response.status == .ok else {
                app.logger.error("Brevo email service startup failed", metadata: [
                    "status_code": .string("\(response.status.code)"),
                    "api_url": .string(config.brevoURL)
                ])
                let error = NSError(domain: "BrevoClient", code: Int(response.status.code), userInfo: [NSLocalizedDescriptionKey: "API authentication failed"])
                throw ServiceRegistryError.serviceInitializationFailed("Brevo API authentication failed with status: \(response.status)", error)
            }
            
            app.logger.info("Brevo email service started successfully", metadata: [
                "api_url": .string(config.brevoURL),
                "api_key_length": .string("\(config.brevoAPIKey.count) characters")
            ])
            
        } catch let error as ConfigurationError {
            app.logger.error("Brevo email service configuration error", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
            
        } catch {
            app.logger.error("Brevo email service startup failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            throw error
        }
    }
    
    /// Gracefully shuts down the Brevo email service during application termination.
    func shutdown(_ app: Application) async throws {
        // Brevo is stateless HTTP-based service, no persistent connections to close
        app.logger.info("Brevo email service shut down gracefully")
    }
}

// MARK: - ServiceHealthCheck Implementation

extension BrevoClient: ServiceHealthCheck {
    /// Performs a health check to determine if Brevo email service is operating correctly.
    func isHealthy() async -> Bool {
        do {
            let config = try app.configuration.services
            
            // Test connectivity with a lightweight API call
            let startTime = Date()
            let response = try await app.client.get(
                URI(string: config.brevoURL + "/account"),
                headers: .init([
                    ("accept", "application/json"),
                    ("api-key", config.brevoAPIKey)
                ])
            )
            let responseTime = Date().timeIntervalSince(startTime)
            
            // Check response status
            guard response.status == .ok else {
                app.logger.warning("Brevo health check: API returned non-OK status", metadata: [
                    "status_code": .string("\(response.status.code)")
                ])
                return false
            }
            
            // Check response time is reasonable (under 5 seconds for healthy service)
            guard responseTime < 5.0 else {
                app.logger.warning("Brevo health check: slow response time", metadata: [
                    "response_time_ms": .string(String(format: "%.2f", responseTime * 1000))
                ])
                return false
            }
            
            return true
            
        } catch {
            app.logger.warning("Brevo health check failed", metadata: [
                "error": .string(error.localizedDescription)
            ])
            return false
        }
    }
    
    /// Provides a human-readable name for this service's health check.
    func healthCheckName() -> String {
        "Brevo Email Service"
    }
}

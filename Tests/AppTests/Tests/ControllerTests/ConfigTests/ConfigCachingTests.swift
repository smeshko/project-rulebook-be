@testable import App
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigCachingTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Config endpoint caches response on first request")
    func configEndpointCachesResponse() async throws {
        await testWorld.resetAll()

        // Seed config data
        try await testWorld.configs.seed()

        // First request - should hit DB and cache result
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == true)
        })

        // Second request - should hit cache (verify by checking response is same)
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == true)
        })
    }

    @Test("Admin update invalidates cache")
    func adminUpdateInvalidatesCache() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data
        try await testWorld.configs.seed()

        // First request to cache the response
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == true)
        })

        // Update config via admin endpoint
        let updateRequest = Config.Admin.UpdateRequest(
            value: "false",
            type: nil
        )

        try await app.test(.PUT, "api/v1/admin/config/enableNewScanner", user: adminUser, content: updateRequest, afterResponse: { response in
            #expect(response.status == .ok)
        })

        // After update, public endpoint should return new value (cache was invalidated)
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["enableNewScanner"] == false) // Updated value
        })
    }

    @Test("Admin create invalidates cache")
    func adminCreateInvalidatesCache() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed initial config data
        try await testWorld.configs.seed()

        // First request to cache the response
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["newFeatureFlag"] == nil) // Not present initially
        })

        // Create new config entry via admin endpoint
        let createRequest = Config.Admin.CreateRequest(
            key: "newFeatureFlag",
            value: "true",
            type: "boolean"
        )

        try await app.test(.POST, "api/v1/admin/config", user: adminUser, content: createRequest, afterResponse: { response in
            #expect(response.status == .ok)
        })

        // After create, public endpoint should include new flag (cache was invalidated)
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["newFeatureFlag"] == true) // New flag present
        })
    }

    @Test("Admin delete invalidates cache")
    func adminDeleteInvalidatesCache() async throws {
        await testWorld.resetAll()

        // Create admin user
        let adminUser = try await testWorld.dataFactory.createAdminUser()

        // Seed config data
        try await testWorld.configs.seed()

        // First request to cache the response
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["showPromotion"] != nil) // Present initially
        })

        // Delete config entry via admin endpoint
        try await app.test(.DELETE, "api/v1/admin/config/showPromotion", user: adminUser) { response in
            #expect(response.status == .ok)
        }

        // After delete, public endpoint should not include deleted flag (cache was invalidated)
        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)
            #expect(config.featureFlags["showPromotion"] == nil) // Deleted flag not present
        })
    }

    @Test("Config response includes correct typed values")
    func configResponseIncludesCorrectTypedValues() async throws {
        await testWorld.resetAll()

        // Seed config data
        try await testWorld.configs.seed()

        try await app.test(.GET, "api/v1/config", afterResponse: { response in
            #expect(response.status == .ok)
            let config = try response.content.decode(Config.Response.self)

            // Boolean flags
            #expect(config.featureFlags["enableNewScanner"] == true)
            #expect(config.featureFlags["showPromotion"] == false)

            // Version string
            #expect(config.version == "1.0.0")
        })
    }
}

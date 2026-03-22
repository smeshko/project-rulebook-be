@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct CacheWarmingEndpointTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let warmPath = "api/admin/cache/warm"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Warming endpoint requires authentication", .tags(.p0Critical, .caching, .integration))
    func warmUnauthenticatedFails() async throws {
        await testWorld.resetAll()

        try await app.test(.POST, warmPath) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Warming endpoint requires admin role", .tags(.p0Critical, .caching, .integration))
    func warmNonAdminFails() async throws {
        await testWorld.resetAll()
        let nonAdmin = try UserAccountModel.mock(app: app)
        try await app.repositories.users.create(nonAdmin)

        try await app.test(.POST, warmPath, user: nonAdmin) { response in
            #expect(response.status == .unauthorized)
        }
    }

    @Test("Admin can trigger cache warming", .tags(.p0Critical, .caching, .integration))
    func warmSucceedsForAdmin() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Set up a CacheWarmingJob on the app so the endpoint doesn't fail
        let job = CacheWarmingJob(app: app)
        app.cacheWarmingJob = job

        try await app.test(.POST, warmPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(CacheAdmin.Warm.Response.self, response) { warmResponse in
                #expect(warmResponse.status == "started")
                #expect(warmResponse.gamesToWarm >= 0)
            }
        }

        job.shutdown()
    }

    @Test("Warming response includes correct game count", .tags(.p1Core, .caching, .integration))
    func warmResponseIncludesGameCount() async throws {
        await testWorld.resetAll()
        let admin = try await testWorld.dataFactory.createAdminUser()
        try await app.repositories.users.create(admin)

        // Insert some game request stats
        try await app.autoMigrate()
        let stats1 = GameRequestStats(sanitizedGameTitle: "catan", requestCount: 100, lastRequestedAt: Date())
        let stats2 = GameRequestStats(sanitizedGameTitle: "risk", requestCount: 50, lastRequestedAt: Date())
        try await stats1.create(on: app.db)
        try await stats2.create(on: app.db)

        let job = CacheWarmingJob(app: app)
        app.cacheWarmingJob = job

        try await app.test(.POST, warmPath, user: admin) { response in
            #expect(response.status == .ok)
            expectContent(CacheAdmin.Warm.Response.self, response) { warmResponse in
                #expect(warmResponse.gamesToWarm == 2)
            }
        }

        job.shutdown()
    }
}

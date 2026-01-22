@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct RemoteConfigRepositoryTests {
    let app: Application
    let testWorld: IsolatedTestWorld

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    @Test("Repository creates config", .tags(.p1Core, .remoteConfig, .database))
    func createConfig() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(
            key: "testKey",
            value: "testValue",
            valueType: .string,
            category: .settings
        )

        try await app.repositories.remoteConfigs.create(config)

        let found = try await app.repositories.remoteConfigs.find(key: "testKey")
        #expect(found != nil)
        #expect(found?.value == "testValue")
        #expect(found?.valueType == .string)
        #expect(found?.category == .settings)
    }

    @Test("Repository finds all configs", .tags(.p1Core, .remoteConfig, .database))
    func findAllConfigs() async throws {
        await testWorld.resetAll()

        let config1 = RemoteConfigModel(key: "key1", value: "value1", valueType: .string, category: .settings)
        let config2 = RemoteConfigModel(key: "key2", value: "true", valueType: .boolean, category: .featureFlags)
        let config3 = RemoteConfigModel(key: "key3", value: "42", valueType: .integer, category: .settings)

        try await app.repositories.remoteConfigs.create(config1)
        try await app.repositories.remoteConfigs.create(config2)
        try await app.repositories.remoteConfigs.create(config3)

        let allConfigs = try await app.repositories.remoteConfigs.findAll()
        #expect(allConfigs.count == 3)
    }

    @Test("Repository finds config by key", .tags(.p1Core, .remoteConfig, .database))
    func findByKey() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(key: "uniqueKey", value: "uniqueValue", valueType: .string, category: .settings)
        try await app.repositories.remoteConfigs.create(config)

        let found = try await app.repositories.remoteConfigs.find(key: "uniqueKey")
        #expect(found != nil)
        #expect(found?.key == "uniqueKey")
        #expect(found?.value == "uniqueValue")

        let notFound = try await app.repositories.remoteConfigs.find(key: "nonExistentKey")
        #expect(notFound == nil)
    }

    @Test("Repository updates config", .tags(.p1Core, .remoteConfig, .database))
    func updateConfig() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(key: "updateKey", value: "oldValue", valueType: .string, category: .settings)
        try await app.repositories.remoteConfigs.create(config)

        config.value = "newValue"
        try await app.repositories.remoteConfigs.update(config)

        let updated = try await app.repositories.remoteConfigs.find(key: "updateKey")
        #expect(updated?.value == "newValue")
    }

    @Test("Repository deletes config by key", .tags(.p1Core, .remoteConfig, .database))
    func deleteByKey() async throws {
        await testWorld.resetAll()

        let config = RemoteConfigModel(key: "deleteKey", value: "value", valueType: .string, category: .settings)
        try await app.repositories.remoteConfigs.create(config)

        // Verify it exists
        let exists = try await app.repositories.remoteConfigs.find(key: "deleteKey")
        #expect(exists != nil)

        // Delete it
        try await app.repositories.remoteConfigs.delete(key: "deleteKey")

        // Verify it's gone
        let deleted = try await app.repositories.remoteConfigs.find(key: "deleteKey")
        #expect(deleted == nil)
    }

    @Test("Repository counts configs", .tags(.p1Core, .remoteConfig, .database))
    func countConfigs() async throws {
        await testWorld.resetAll()

        let initialCount = try await app.repositories.remoteConfigs.count()
        #expect(initialCount == 0)

        try await app.repositories.remoteConfigs.create(
            RemoteConfigModel(key: "key1", value: "v1", valueType: .string, category: .settings)
        )
        try await app.repositories.remoteConfigs.create(
            RemoteConfigModel(key: "key2", value: "v2", valueType: .string, category: .settings)
        )

        let count = try await app.repositories.remoteConfigs.count()
        #expect(count == 2)
    }
}

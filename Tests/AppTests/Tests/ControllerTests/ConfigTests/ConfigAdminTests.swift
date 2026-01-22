@testable import App
import Fluent
import VaporTesting
import Testing

@Suite(.serialized)
struct ConfigAdminTests {
    let app: Application
    let testWorld: IsolatedTestWorld
    let basePath = "api/v1/config"

    init() async throws {
        testWorld = try await IsolatedTestWorld()
        app = testWorld.app
    }

    // MARK: - Authentication Tests

    @Test("GET /api/v1/config/list requires authentication", .tags(.p0Critical, .auth, .integration))
    func getListRequiresAuth() async throws {
        await testWorld.resetAll()

        try await app.test(.GET, "\(basePath)/list", afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("GET /api/v1/config/list requires admin role", .tags(.p0Critical, .auth, .integration))
    func getListRequiresAdmin() async throws {
        await testWorld.resetAll()

        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(nonAdmin)

        try await app.test(.GET, "\(basePath)/list", user: nonAdmin) { res in
            #expect(res.status == .unauthorized)
        }
    }

    @Test("POST /api/v1/config requires authentication", .tags(.p0Critical, .auth, .integration))
    func postConfigRequiresAuth() async throws {
        await testWorld.resetAll()

        let createRequest = Config.Create.Request(
            key: "testKey",
            value: "testValue",
            valueType: .string,
            category: .setting
        )

        try await app.test(.POST, basePath, content: createRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("POST /api/v1/config requires admin role", .tags(.p0Critical, .auth, .integration))
    func postConfigRequiresAdmin() async throws {
        await testWorld.resetAll()

        // Create a non-admin user
        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(nonAdmin)

        let createRequest = Config.Create.Request(
            key: "testKey",
            value: "testValue",
            valueType: .string,
            category: .setting
        )

        try await app.test(.POST, basePath, user: nonAdmin, content: createRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("PATCH /api/v1/config/:id requires admin role", .tags(.p0Critical, .auth, .integration))
    func patchConfigRequiresAdmin() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "testKey",
            value: "original",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(nonAdmin)

        let updateRequest = Config.Update.Request(value: "modified", valueType: nil, category: nil)

        try await app.test(.PATCH, "\(basePath)/\(config.id!)", user: nonAdmin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .unauthorized)
        })
    }

    @Test("DELETE /api/v1/config/:id requires admin role", .tags(.p0Critical, .auth, .integration))
    func deleteConfigRequiresAdmin() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "testKey",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let nonAdmin = try UserAccountModel.mock(app: app, isAdmin: false)
        try await app.repositories.users.create(nonAdmin)

        try await app.test(.DELETE, "\(basePath)/\(config.id!)", user: nonAdmin) { res in
            #expect(res.status == .unauthorized)
        }
    }

    // MARK: - CRUD Tests (Admin)

    @Test("POST /api/v1/config creates config entry successfully", .tags(.p1Core, .integration))
    func postConfigCreatesEntry() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = Config.Create.Request(
            key: "newFeature",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, basePath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Entry.Response.self, res) { response in
                #expect(response.key == "newFeature")
                #expect(response.value == .boolean(true))
                #expect(response.valueType == .boolean)
                #expect(response.category == .featureFlag)
            }
        })

        // Verify it was created in the repository
        let count = try await testWorld.configs.count()
        #expect(count == 1)
    }

    @Test("POST /api/v1/config rejects duplicate key", .tags(.p1Core, .integration))
    func postConfigRejectsDuplicateKey() async throws {
        await testWorld.resetAll()

        let existing = ConfigEntryModel(
            key: "existingKey",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(existing)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = Config.Create.Request(
            key: "existingKey",
            value: "newValue",
            valueType: .string,
            category: .setting
        )

        try await app.test(.POST, basePath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .conflict)
        })
    }

    @Test("POST /api/v1/config validates required fields", .tags(.p1Core, .integration))
    func postConfigValidatesRequiredFields() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        // Empty key should fail validation
        let invalidRequest = Config.Create.Request(
            key: "",
            value: "value",
            valueType: .string,
            category: .setting
        )

        try await app.test(.POST, basePath, user: admin, content: invalidRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("PATCH /api/v1/config/:id updates config entry", .tags(.p1Core, .integration))
    func patchConfigUpdatesEntry() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "toUpdate",
            value: "original",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let updateRequest = Config.Update.Request(
            value: "updated",
            valueType: nil,
            category: nil
        )

        try await app.test(.PATCH, "\(basePath)/\(config.id!)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Entry.Response.self, res) { response in
                #expect(response.key == "toUpdate")
                #expect(response.value == .string("updated"))
            }
        })
    }

    @Test("PATCH /api/v1/config/:id returns 404 for non-existent entry", .tags(.p1Core, .integration))
    func patchConfigReturns404ForNonExistent() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()
        let updateRequest = Config.Update.Request(value: "value", valueType: nil, category: nil)

        try await app.test(.PATCH, "\(basePath)/\(nonExistentId)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .notFound)
        })
    }

    @Test("DELETE /api/v1/config/:id removes config entry", .tags(.p1Core, .integration))
    func deleteConfigRemovesEntry() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "toDelete",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        try await app.test(.DELETE, "\(basePath)/\(config.id!)", user: admin) { res in
            #expect(res.status == .noContent)
        }

        // Verify it was deleted
        let count = try await testWorld.configs.count()
        #expect(count == 0)
    }

    @Test("DELETE /api/v1/config/:id returns 404 for non-existent entry", .tags(.p1Core, .integration))
    func deleteConfigReturns404ForNonExistent() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let nonExistentId = UUID()

        try await app.test(.DELETE, "\(basePath)/\(nonExistentId)", user: admin) { res in
            #expect(res.status == .notFound)
        }
    }

    @Test("GET /api/v1/config/list returns all entries with details", .tags(.p1Core, .integration))
    func getListReturnsAllEntries() async throws {
        await testWorld.resetAll()

        let config1 = ConfigEntryModel(
            key: "key1",
            value: "true",
            valueType: .boolean,
            category: .featureFlag
        )
        let config2 = ConfigEntryModel(
            key: "key2",
            value: "42",
            valueType: .integer,
            category: .setting
        )

        try await testWorld.configs.create(config1)
        try await testWorld.configs.create(config2)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        try await app.test(.GET, "\(basePath)/list", user: admin) { res in
            #expect(res.status == .ok)
            expectContent(Config.List.Response.self, res) { response in
                #expect(response.entries.count == 2)
            }
        }
    }

    // MARK: - Cache Invalidation Tests

    @Test("POST /api/v1/config invalidates cache", .tags(.p1Core, .caching, .integration))
    func postConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        // First, seed a config and make a GET request to populate cache
        let existing = ConfigEntryModel(
            key: "existing",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(existing)

        // GET request to populate cache
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings.count == 1)
            }
        })

        // Create new config as admin (should invalidate cache)
        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let createRequest = Config.Create.Request(
            key: "newKey",
            value: "newValue",
            valueType: .string,
            category: .setting
        )

        try await app.test(.POST, basePath, user: admin, content: createRequest, afterResponse: { res in
            #expect(res.status == .ok)
        })

        // GET request should now show both entries (cache was invalidated)
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings.count == 2)
            }
        })
    }

    @Test("PATCH /api/v1/config/:id invalidates cache", .tags(.p1Core, .caching, .integration))
    func patchConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "cacheTest",
            value: "original",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        // GET request to populate cache
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings["cacheTest"] == .string("original"))
            }
        })

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let updateRequest = Config.Update.Request(value: "updated", valueType: nil, category: nil)

        try await app.test(.PATCH, "\(basePath)/\(config.id!)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
        })

        // GET request should now show updated value (cache was invalidated)
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings["cacheTest"] == .string("updated"))
            }
        })
    }

    @Test("DELETE /api/v1/config/:id invalidates cache", .tags(.p1Core, .caching, .integration))
    func deleteConfigInvalidatesCache() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "toDelete",
            value: "value",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        // GET request to populate cache
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings.count == 1)
            }
        })

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        try await app.test(.DELETE, "\(basePath)/\(config.id!)", user: admin) { res in
            #expect(res.status == .noContent)
        }

        // GET request should now show empty (cache was invalidated)
        try await app.test(.GET, basePath, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Get.Response.self, res) { response in
                #expect(response.settings.isEmpty)
            }
        })
    }

    // MARK: - Value/Type Validation Tests

    @Test("POST /api/v1/config rejects invalid value for boolean type", .tags(.p1Core, .integration))
    func postConfigRejectsInvalidBooleanValue() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let invalidRequest = Config.Create.Request(
            key: "invalidBool",
            value: "notABoolean",
            valueType: .boolean,
            category: .featureFlag
        )

        try await app.test(.POST, basePath, user: admin, content: invalidRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("POST /api/v1/config rejects invalid value for integer type", .tags(.p1Core, .integration))
    func postConfigRejectsInvalidIntegerValue() async throws {
        await testWorld.resetAll()

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        let invalidRequest = Config.Create.Request(
            key: "invalidInt",
            value: "notAnInteger",
            valueType: .integer,
            category: .setting
        )

        try await app.test(.POST, basePath, user: admin, content: invalidRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("PATCH /api/v1/config/:id rejects incompatible type change", .tags(.p1Core, .integration))
    func patchConfigRejectsIncompatibleTypeChange() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "stringValue",
            value: "hello",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        // Try to change type to integer without changing value
        let updateRequest = Config.Update.Request(value: nil, valueType: .integer, category: nil)

        try await app.test(.PATCH, "\(basePath)/\(config.id!)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .badRequest)
        })
    }

    @Test("PATCH /api/v1/config/:id allows compatible type change with new value", .tags(.p1Core, .integration))
    func patchConfigAllowsCompatibleTypeChange() async throws {
        await testWorld.resetAll()

        let config = ConfigEntryModel(
            key: "typeChange",
            value: "hello",
            valueType: .string,
            category: .setting
        )
        try await testWorld.configs.create(config)

        let admin = try UserAccountModel.mock(app: app, isAdmin: true)
        try await app.repositories.users.create(admin)

        // Change type to integer with a valid integer value
        let updateRequest = Config.Update.Request(value: "42", valueType: .integer, category: nil)

        try await app.test(.PATCH, "\(basePath)/\(config.id!)", user: admin, content: updateRequest, afterResponse: { res in
            #expect(res.status == .ok)
            expectContent(Config.Entry.Response.self, res) { response in
                #expect(response.value == .integer(42))
                #expect(response.valueType == .integer)
            }
        })
    }
}

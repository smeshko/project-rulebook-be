import Vapor

struct RemoteConfigModule: ModuleInterface {

    let router = RemoteConfigRouter()

    func boot(_ app: Application) throws {
        // Register migration
        app.migrations.add(RemoteConfigMigrations.v1())

        // Register repository
        app.remoteConfigRepository = DatabaseRemoteConfigRepository(database: app.db)

        // Boot routes
        try router.boot(routes: app.routes)
    }

    func setUp(_ app: Application) throws {
        // No additional setup required
    }
}

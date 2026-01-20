import Vapor

struct RemoteConfigModule: ModuleInterface {

    let router = RemoteConfigRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(RemoteConfigMigrations.v1())
        try router.boot(routes: app.routes)
    }
}

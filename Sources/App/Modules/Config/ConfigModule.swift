import Vapor

struct ConfigModule: ModuleInterface {

    let router = ConfigRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(ConfigMigrations.v1())
        try router.boot(routes: app.routes)
    }
}

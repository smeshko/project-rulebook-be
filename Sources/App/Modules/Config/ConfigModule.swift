import Vapor

struct ConfigModule: ModuleInterface {

    let router = ConfigRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(ConfigMigrations.v1())
        app.migrations.add(ConfigMigrations.v1Seed())
        try router.boot(routes: app.routes)
    }
}

import Vapor

struct WaitlistModule: ModuleInterface {

    let router = WaitlistRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(WaitlistMigrations.v1())
        try router.boot(routes: app.routes)
    }
}

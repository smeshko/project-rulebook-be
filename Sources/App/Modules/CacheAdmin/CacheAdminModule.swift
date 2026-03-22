import Fluent
import Vapor

struct CacheAdminModule: ModuleInterface {
    let router = CacheAdminRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(CacheAdminMigrations.v1())
        try router.boot(routes: app.routes)
    }
}
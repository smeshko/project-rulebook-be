import Vapor

struct AuthModule: ModuleInterface {
    let router = AuthRouter()
    
    func boot(_ app: Application) throws {
        app.migrations.add(AuthMigrations.v1())
        app.migrations.add(PerformanceIndexesMigration())
        
        try router.boot(routes: app.routes)
    }
}

import Fluent
import Vapor

struct RulesGenerationModule: ModuleInterface {
    let router = RulesGenerationRouter()
    
    func boot(_ app: Application) throws {
        app.migrations.add(RulesGenerationMigrations.v1())
        try router.boot(routes: app.routes)
    }
}

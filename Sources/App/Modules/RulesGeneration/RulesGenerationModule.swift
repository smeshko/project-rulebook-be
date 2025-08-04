import Vapor

struct RulesGenerationModule: ModuleInterface {
    let router = RulesGenerationRouter()
    
    func boot(_ app: Application) throws {
        try router.boot(routes: app.routes)
    }
}

import Vapor

struct CacheAdminModule: ModuleInterface {
    let router = CacheAdminRouter()
    
    func boot(_ app: Application) throws {
        try router.boot(routes: app.routes)
    }
}
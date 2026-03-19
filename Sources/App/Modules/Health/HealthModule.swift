import Vapor

struct HealthModule: ModuleInterface {
    let router = HealthRouter()

    func boot(_ app: Application) throws {
        try router.boot(routes: app.routes)
    }
}

import Vapor

struct FeedbackModule: ModuleInterface {

    let router = FeedbackRouter()
    let adminRouter = FeedbackAdminRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(FeedbackMigrations.v1())
        try router.boot(routes: app.routes)
        try adminRouter.boot(routes: app.routes)
    }
}

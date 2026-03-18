import Vapor

struct ReceiptsModule: ModuleInterface {

    let router = ReceiptsRouter()

    func boot(_ app: Application) throws {
        app.migrations.add(ReceiptsMigrations.v1())
        app.migrations.add(ReceiptsMigrations.v2())
        app.migrations.add(ReceiptsMigrations.v3())

        try router.boot(routes: app.routes)
    }
}

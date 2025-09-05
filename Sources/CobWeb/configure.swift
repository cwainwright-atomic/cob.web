import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    
    app.databases.default(to: .sqlite)

    app.migrations.add(CobOrder.Migration())
    app.migrations.add(RecurringOrder.Migrtaion())
    app.migrations.add(RecurringOrderException.Migration())
    app.migrations.add(WeekOrder.Migration())
    app.migrations.add(User.Migration())
    app.migrations.add(UserToken.Migration())
    
    try await app.autoMigrate().get()
    
    // register routes
    try routes(app)
}

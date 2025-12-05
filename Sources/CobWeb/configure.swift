import NIOSSL
import Fluent
import FluentSQLiteDriver
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    if app.environment == .testing {
        app.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        app.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }
    
    app.databases.default(to: .sqlite)

    app.migrations.add(User.Migration())
    app.migrations.add(CobOrder.Migration())
    app.migrations.add(UserToken.Migration())
    app.migrations.add(RecurringOrder.Migration())
    app.migrations.add(RecurringOrderException.Migration())
    
    try await app.autoMigrate().get()
    
    // register routes
    try routes(app)
}

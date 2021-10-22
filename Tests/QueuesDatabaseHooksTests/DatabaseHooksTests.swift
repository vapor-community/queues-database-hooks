import QueuesDatabaseHooks
import Queues
import XCTQueues
import XCTVapor
import Fluent
import FluentSQLiteDriver
import XCTest

final class QueuesDatabaseHooksTests: XCTestCase {
    var app: Application!
    
    override func setUpWithError() throws {
        self.app = Application(.testing)
        self.app.databases.use(.sqlite(.memory, maxConnectionsPerEventLoop: 1), as: .sqlite)
        self.app.migrations.add(QueueDatabaseEntryMigration())
        try self.app.migrator.setupIfNeeded().wait()
        try self.app.migrator.prepareBatch().wait()
        self.app.queues.use(.test)
        self.app.queues.add(QueuesDatabaseNotificationHook(db: self.app.db, errorClosure: { $0.localizedDescription }, payloadClosure: { $0 }))
    }
    
    override func tearDownWithError() throws {
        self.app.shutdown()
    }
    
    func testJobLifecycle() throws {
        struct Foo: Job {
            struct Payload: Codable {}
            
            func dequeue(_ context: QueueContext, _: Payload) -> EventLoopFuture<Void> {
                context.eventLoop.makeSucceededVoidFuture()
            }
            
            func error(_ context: QueueContext, _: Error, _: Payload) -> EventLoopFuture<Void> {
                context.eventLoop.makeSucceededVoidFuture()
            }
        }
        
        self.app.queues.add(Foo())
        self.app.get("foo") { $0.queue.dispatch(Foo.self, .init()).map { _ in "done" } }
        try app.testable().test(.GET, "/foo") { XCTAssertEqual($0.body.string, "done") }
        
        let entries1 = try QueueDatabaseEntry.query(on: self.app.db).all().wait()
        XCTAssertEqual(entries1.count, 1)
        XCTAssertEqual(entries1.first?.status, .queued)
        XCTAssertNil(entries1.first?.dequeuedAt)
        XCTAssertNil(entries1.first?.completedAt)
        XCTAssertNil(entries1.first?.errorString)
        
        try app.queues.queue.worker.run().wait()
        
        let entries2 = try QueueDatabaseEntry.query(on: self.app.db).all().wait()
        XCTAssertEqual(entries2.count, 1)
        XCTAssertEqual(entries2.first?.status, .success)
        XCTAssertNotNil(entries2.first?.dequeuedAt)
        XCTAssertNotNil(entries2.first?.completedAt)
        XCTAssertNil(entries2.first?.errorString)
    }
}

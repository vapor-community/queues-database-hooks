import Foundation
import Queues
import FluentKit

/// A `NotificationHook` that can be added to the queues package to track the status of all successful and failed jobs
public struct QueuesDatabaseNotificationHook: NotificationHook {
    /// Error-transformation closure.
    private let closure: (Error) -> (String)

    /// The database to run the queries on
    public let database: Database

    /// Creates a default `QueuesDatabaseNotificationHook`
    /// - Returns: A `QueuesDatabaseNotificationHook` notification hook handler
    public static func `default`(db: Database) -> QueuesDatabaseNotificationHook {
        return .init(db: db) { error -> String in
            return error.localizedDescription
        }
    }

    /// Create a new `QueuesNotificationHook`.
    ///
    /// - parameters:
    ///     - closure: Error-transformation closure. Converts `Error` to `String`.
    public init(db: Database, _ closure: @escaping (Error) -> (String)) {
        self.database = db
        self.closure = closure
    }

    /// Called when the job is first dispatched
    /// - Parameters:
    ///   - job: The `JobData` associated with the job
    ///   - eventLoop: The eventLoop
    public func dispatched(job: NotificationJobData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry(jobId: job.id,
                           jobName: job.jobName,
                           payload: Data(job.payload),
                           maxRetryCount: job.maxRetryCount,
                           delayUntil: job.delayUntil,
                           queuedAt: job.queuedAt,
                           dequeuedAt: nil,
                           completedAt: nil,
                           errorString: nil,
                           status: .queued).save(on: database)
    }

    /// Called when the job is dequeued
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func dequeued(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$status, to: .running)
            .set(\.$dequeuedAt, to: Date())
            .update()
    }

    /// Called when the job succeeds
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func success(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$status, to: .success)
            .set(\.$completedAt, to: Date())
            .update()
    }

    /// Called when the job returns an error
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - error: The error that caused the job to fail
    ///   - eventLoop: The eventLoop
    public func error(jobId: String, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry
            .query(on: database)
            .filter(\.$jobId == jobId)
            .set(\.$status, to: .error)
            .set(\.$errorString, to: closure(error))
            .set(\.$completedAt, to: Date())
            .update()
    }
}

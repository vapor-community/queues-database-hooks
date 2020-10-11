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

    /// Called when successfully dequeuing a job
    /// - Parameters:
    ///   - job: The `NotificationJobData`
    ///   - eventLoop: The `EventLoop` that can be used to run operations
    /// - Returns: `Void` indicating completion
    public func success(job: NotificationJobData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry(jobId: job.id,
                           jobName: job.jobName,
                           payload: Data(),
                           maxRetryCount: job.maxRetryCount,
                           delayUntil: job.delayUntil,
                           queuedAt: job.queuedAt,
                           errorString: nil).save(on: database)
    }

    /// Called when dequeing a job returns an error
    /// - Parameters:
    ///   - job: The `NotificationJobData`
    ///   - error: The `Error` that was passed through. Will get passed into the `closure` to transform it to a string
    ///   - eventLoop: The `EventLoop` that can be used to run operations
    /// - Returns: `Void` indicating completion
    public func error(job: NotificationJobData, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        QueueDatabaseEntry(jobId: job.id,
                           jobName: job.jobName,
                           payload: Data(),
                           maxRetryCount: job.maxRetryCount,
                           delayUntil: job.delayUntil,
                           queuedAt: job.queuedAt,
                           errorString: closure(error)).save(on: database)
    }
}

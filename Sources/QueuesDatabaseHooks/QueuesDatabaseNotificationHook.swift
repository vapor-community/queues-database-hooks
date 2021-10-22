import Foundation
import Queues
import FluentKit

/// A `NotificationHook` that can be added to the queues package to track the status of all successful and failed jobs
public struct QueuesDatabaseNotificationHook: JobEventDelegate {
    /// Transforms an `Error` to a `String` to store in the database for a failing job.
    private let errorClosure: (Error) -> (String)

    /// A hook which allows modifying (such as redacting) the payload stored in the database for a dispatched job.
    private let payloadClosure: (JobEventData) -> (JobEventData)

    /// The database in which job information is stored.
    public let database: Database

    /// Creates a default `QueuesDatabaseNotificationHook`
    /// - Returns: A `QueuesDatabaseNotificationHook` notification hook handler
    public static func `default`(db: Database) -> QueuesDatabaseNotificationHook {
        return .init(db: db) { error -> (String) in
            return error.localizedDescription
        } payloadClosure: { data -> (JobEventData) in
            return data
        }
    }

    /// Create a new `QueuesNotificationHook`.
    ///
    /// - Parameters:
    ///  - db: The database in which job information should be stored.
    ///  - errorClosure: A closure to turn an `Error` into a `String` that is stored in the database for a failed job.
    ///  - payloadClosure: A closure which allows editing or removing the job payload which is saved to the database.
    public init(db: Database, errorClosure: @escaping (Error) -> (String), payloadClosure: @escaping (JobEventData) -> (JobEventData)) {
        self.database = db
        self.errorClosure = errorClosure
        self.payloadClosure = payloadClosure
    }

    /// Called when the job is first dispatched to a queue.
    /// - Parameters:
    ///   - job: The `JobEventData` associated with the job.
    ///   - eventLoop: The `EventLoop` of the queue the job was dispatched to.
    public func dispatched(job: JobEventData, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        let data = payloadClosure(job)
        
        return QueueDatabaseEntry.recordDispatch(
            jobId: data.id,
            jobName: data.jobName,
            queueName: data.queueName,
            payload: Data(data.payload),
            maxRetryCount: data.maxRetryCount,
            delayUntil: data.delayUntil,
            dispatchTimestamp: data.queuedAt,
            on: self.database
        ).map {
            self.database.logger.info("\(job.id) - Added route to database")
        }
    }

    /// Called when the job is dequeued
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func didDequeue(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of running")
        
        return QueueDatabaseEntry.recordDequeue(
            jobId: jobId,
            dequeueTimestamp: Date(),
            on: self.database
        ).map {
            self.database.logger.info("\(jobId) - Done updating to status of running")
        }
    }

    /// Called when the job succeeds
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - eventLoop: The eventLoop
    public func success(jobId: String, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of success")
        
        return QueueDatabaseEntry.recordCompletion(
            jobId: jobId,
            completionTimestamp: Date(),
            errorString: nil,
            on: self.database
        ).map {
            self.database.logger.info("\(jobId) - Done updating to status of success")
        }
    }

    /// Called when the job returns an error
    /// - Parameters:
    ///   - jobId: The id of the Job
    ///   - error: The error that caused the job to fail
    ///   - eventLoop: The eventLoop
    public func error(jobId: String, error: Error, eventLoop: EventLoop) -> EventLoopFuture<Void> {
        self.database.logger.info("\(jobId) - Updating to status of error")
        
        return QueueDatabaseEntry.recordCompletion(
            jobId: jobId,
            completionTimestamp: Date(),
            errorString: errorClosure(error),
            on: self.database
        ).map {
            self.database.logger.info("\(jobId) - Done updating to status of error")
        }
    }
}

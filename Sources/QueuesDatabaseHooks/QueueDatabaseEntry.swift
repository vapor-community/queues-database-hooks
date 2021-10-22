import Foundation
import FluentKit
import SQLKit

/// Stores information about a `Queue` job.
///
/// A record is added when the job is dispatched and updated with the final status
/// when it succeeds or fails.
public final class QueueDatabaseEntry: Model {
    public static let schema = "_queue_job_completions"

    /// The database primary key.
    @ID(key: .id)
    public var id: UUID?

    /// The `jobId` from the `queues` package.
    @Field(key: "jobId")
    public var jobId: String

    /// The name of the job.
    @Field(key: "jobName")
    public var jobName: String

    /// The name of the queue on which the job was run.
    @Field(key: "queueName")
    public var queueName: String

    /// The data associated with the job.
    @Field(key: "payload")
    public var payload: Data

    /// The job's retry count.
    @Field(key: "maxRetryCount")
    public var maxRetryCount: Int

    /// The `delayUntil` date from the `queues` package.
    @OptionalField(key: "delayUntil")
    public var delayUntil: Date?

    /// The `queuedAt` timestamp from the `queues` package.
    @Field(key: "queuedAt")
    public var queuedAt: Date

    /// The timestamp at which the job was dequeued, or `nil` if it is still queued.
    @Timestamp(key: "dequeuedAt", on: .none)
    public var dequeuedAt: Date?

    /// The timestamp at which the job was completed, or `nil` if it is not complete.
    ///
    /// A job is considered complete regardless of success or failure.
    ///
    /// - Precondition: If this property is not `nil`, `dequeuedAt` must not be `nil`.
    @Timestamp(key: "completedAt", on: .none)
    public var completedAt: Date?

    /// The error string for the job, or `nil` if it succeeded or is not yet complete.
    ///
    /// - Precondition: If this property is not `nil`, `completedAt` must not be `nil`.
    @OptionalField(key: "errorString")
    public var errorString: String?

    /// The status of the job.
    @Field(key: "status")
    public var status: Status

    /// The timestamp at which the database record of the job was created.
    ///
    /// This should usually be within a few ms of `queuedAt`, unless under heavy load.
    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    /// The timestamp at which the database record was last updated.
    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    /// A queue job's status.
    public enum Status: Int, CaseIterable, Codable {
        /// The job is queued but not yet picked up for processing.
        case queued

        /// The job has been moved to the processing queue and is currently running.
        case running

        /// The job was completed successfully.
        case success

        /// The job failed.
        case error
    }

    public init() { }

    public init(jobId: String,
                jobName: String,
                queueName: String,
                payload: Data,
                maxRetryCount: Int,
                delayUntil: Date?,
                queuedAt: Date,
                dequeuedAt: Date?,
                completedAt: Date?,
                errorString: String?,
                status: Status
    ) {
        self.jobId = jobId
        self.jobName = jobName
        self.queueName = queueName
        self.payload = payload
        self.maxRetryCount = maxRetryCount
        self.delayUntil = delayUntil
        self.queuedAt = queuedAt
        self.errorString = errorString
        self.status = status
        self.completedAt = completedAt
        self.createdAt = nil
        self.updatedAt = nil
    }
}

extension QueueDatabaseEntry {
    /// It is a hard error to queue the same `jobId` more than once.
    internal static func recordDispatch(
        jobId: String, jobName: String, queueName: String, payload: Data,
        maxRetryCount: Int, delayUntil: Date?, dispatchTimestamp: Date,
        on database: Database
    ) -> EventLoopFuture<Void> {
        return QueueDatabaseEntry(jobId: jobId, jobName: jobName, queueName: queueName, payload: payload, maxRetryCount: maxRetryCount, delayUntil: delayUntil, queuedAt: dispatchTimestamp, dequeuedAt: nil, completedAt: nil, errorString: nil, status: .queued).create(on: database)
    }
    
    /// Dequeuing an already-running or completed job only sets the dequeuing timestamp iff it wasn't already set.
    internal static func recordDequeue(
        jobId: String, dequeueTimestamp: Date, on database: Database
    ) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
                UPDATE \(ident: QueueDatabaseEntry.schema)
                SET
                    \(ident: "dequeuedAt")=CASE WHEN \(ident: "dequeuedAt") IS NULL THEN \(bind: dequeueTimestamp) ELSE \(ident: "dequeuedAt") END,
                    \(ident: "status")=CASE WHEN \(ident: "status")=\(bind: Status.queued) THEN \(bind: Status.running) ELSE \(ident: "status") END
                WHERE
                    \(ident: "jobId")=\(bind: jobId)
                """)
                .run()
        } else {
            return QueueDatabaseEntry.query(on: database).set(\.$dequeuedAt, to: dequeueTimestamp).filter(\.$dequeuedAt == nil).filter(\.$jobId == jobId).update()
                .flatMap { QueueDatabaseEntry.query(on: database).set(\.$status, to: .running).filter(\.$status == .queued).filter(\.$jobId == jobId).update() }
        }
    }
    
    /// Completing an already-completed job has no effect, even if the final status differs (only the first completion
    /// takes effect, in other words). Completing a still-queued job updates the dequeuing timestamp as well.
    internal static func recordCompletion(
        jobId: String, completionTimestamp: Date, errorString: String?, on database: Database
    ) -> EventLoopFuture<Void> {
        if let sql = database as? SQLDatabase {
            return sql.raw("""
                UPDATE \(ident: QueueDatabaseEntry.schema)
                SET
                    \(ident: "dequeuedAt")=CASE WHEN \(ident: "dequeuedAt") IS NULL THEN \(bind: completionTimestamp) ELSE \(ident: "dequeuedAt") END,
                    \(ident: "completedAt")=CASE WHEN \(ident: "completedAt") IS NULL THEN \(bind: completionTimestamp) ELSE \(ident: "completedAt") END,
                    \(ident: "errorString")=CASE WHEN \(ident: "errorString") IS NULL THEN \(bind: errorString) ELSE \(ident: "errorString") END,
                    \(ident: "status")=CASE WHEN \(ident: "status") IN (\(bind: Status.queued), \(bind: Status.running)) THEN \(bind: errorString == nil ? Status.success : Status.error) ELSE \(ident: "status") END
                WHERE
                    \(ident: "jobId")=\(bind: jobId)
                """)
                .run()
        } else {
            return QueueDatabaseEntry.query(on: database).set(\.$dequeuedAt, to: completionTimestamp).filter(\.$dequeuedAt == nil).filter(\.$jobId == jobId).update()
                .flatMap { QueueDatabaseEntry.query(on: database).set(\.$completedAt, to: completionTimestamp).filter(\.$completedAt == nil).filter(\.$jobId == jobId).update() }
                .flatMap { QueueDatabaseEntry.query(on: database).set(\.$errorString, to: errorString).filter(\.$errorString == nil).filter(\.$jobId == jobId).update() }
                .flatMap { QueueDatabaseEntry.query(on: database).set(\.$status, to: errorString == nil ? .success : .error).filter(\.$status ~~ [.queued, .running]).filter(\.$jobId == jobId).update() }
        }
    }
}

public struct QueueDatabaseEntryMigration: Migration {
    public init() { }

    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema)
            .field(.id, .uuid, .identifier(auto: false))
            .field("jobId", .string, .required)
            .field("jobName", .string, .required)
            .field("queueName", .string, .required)
            .field("payload", .json, .required)
            .field("maxRetryCount", .int, .required)
            .field("delayUntil", .datetime)
            .field("queuedAt", .datetime, .required)
            .field("dequeuedAt", .datetime)
            .field("completedAt", .datetime)
            .field("errorString", .string)
            .field("status", .int8, .required)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .unique(on: "jobId")
            .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema).delete()
    }
}

/// A migration intended for users updating from 0.2.0 to any later prerelease version.
///
/// - Important: If a 1.0.0 release happens, delete this first!
public struct QueueDatabaseEntryUpgradeFrom_0_2_0: Migration {
    public init() { }
    
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema)
            .unique(on: "jobId")
            .update()
    }
    
    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema)
            .deleteUnique(on: "jobId")
            .update()
    }
}

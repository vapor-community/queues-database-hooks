import Foundation
import FluentKit

/// Stores information about a `Queue` job
/// A record gets added when the job is dispatched
/// and then updated with its status when it succeeds or fails
public final class QueueDatabaseEntry: Model {
    public static let schema = "_queue_job_completions"

    @ID(key: .id)
    public var id: UUID?

    /// The `jobId` that came from the queues package
    @Field(key: "jobId")
    public var jobId: String

    /// The name of the job
    @Field(key: "jobName")
    public var jobName: String

    /// The data associated with the job
    @Field(key: "payload")
    public var payload: Data

    /// The retry count for the job
    @Field(key: "maxRetryCount")
    public var maxRetryCount: Int

    /// The `delayUntil` date from the queues package
    @OptionalField(key: "delayUntil")
    public var delayUntil: Date?

    /// The date the job was queued at
    @Field(key: "queuedAt")
    public var queuedAt: Date

    /// The date the job was dequeued at
    @OptionalField(key: "dequeuedAt")
    public var dequeuedAt: Date?

    /// The date the job was completed
    @OptionalField(key: "completedAt")
    public var completedAt: Date?

    /// The error string for the job
    @OptionalField(key: "errorString")
    public var errorString: String?

    /// The status of the job
    @Field(key: "status")
    public var status: Status

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    /// The status of the queue job
    public enum Status: Int, Codable {
        /// The job has been queued but not yet picked up for processing
        case queued

        /// The job has been moved ot the processing queue and is currently running
        case running

        /// The job has finished and it was successful
        case success

        /// The job has finished and it returned an error
        case error
    }

    public init() { }

    public init(jobId: String,
                jobName: String,
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

public struct QueueDatabaseEntryMigration: Migration {
    public init() { }

    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema)
            .field(.id, .uuid, .identifier(auto: false))
            .field("jobId", .string, .required)
            .field("jobName", .string, .required)
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
            .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema).delete()
    }
}

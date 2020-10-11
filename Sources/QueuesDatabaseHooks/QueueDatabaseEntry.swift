import Foundation
import FluentKit

/// Stores information about a `Queue` job
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

    /// The error string for the job
    @Field(key: "errorString")
    public var errorString: String?

    @Timestamp(key: "created_at", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    public var updatedAt: Date?

    public init() { }

    public init(jobId: String, jobName: String, payload: Data, maxRetryCount: Int, delayUntil: Date?, queuedAt: Date, errorString: String?) {
        self.jobId = jobId
        self.jobName = jobName
        self.payload = payload
        self.maxRetryCount = maxRetryCount
        self.delayUntil = delayUntil
        self.queuedAt = queuedAt
        self.errorString = errorString
        self.createdAt = nil
        self.updatedAt = nil
    }
}

public struct QueueDatabaseEntryMigration: Migration {
    public func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema)
            .field(.id, .uuid, .identifier(auto: false))
            .field("jobId", .string, .required)
            .field("payload", .json, .required)
            .field("maxRetryCount", .int, .required)
            .field("delayUntil", .date)
            .field("queuedAt", .data, .required)
            .field("errorString", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema).delete()
    }
}

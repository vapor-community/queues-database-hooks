import Foundation
import FluentKit

/// Stores information about a `Queue` job
/// A record gets added when the job is dispatched and then updated with its status when
/// it succeeds or fails
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

    /// The status of the job
    @Field(key: "status")
    public var status: Status

    /// The date the job was completed
    @Field(key: "completedAt")
    public var completedAt: Date?

    @Timestamp(key: "createdAt", on: .create)
    public var createdAt: Date?

    @Timestamp(key: "updatedAt", on: .update)
    public var updatedAt: Date?

    public enum Status: Int, Codable {
        case dispatched
        case success
        case error
    }

    public init() { }

    public init(jobId: String,
                jobName: String,
                payload: Data,
                maxRetryCount: Int,
                delayUntil: Date?,
                queuedAt: Date,
                errorString: String?,
                status: Status,
                completedAt: Date?)
    {
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
            .field("errorString", .string)
            .field("status", .int8)
            .field("completedAt", .datetime)
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    public func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema(QueueDatabaseEntry.schema).delete()
    }
}

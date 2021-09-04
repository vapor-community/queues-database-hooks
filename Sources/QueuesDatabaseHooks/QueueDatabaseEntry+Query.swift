import Foundation
import FluentKit
import SQLKit
import Vapor

public extension QueueDatabaseEntry {

    /// Returns the current queued count of jobs and current running count
    /// - Parameter db: The Database to run the query on - must be a `SQLDatabase`
    /// - Returns: The data returned from the query
    static func getStatusOfCurrentJobs(db: Database) -> EventLoopFuture<CurrentJobsStatusResponse> {
        guard let sqlDb = db as? SQLDatabase else { return db.eventLoop.future(error: Abort(.badRequest, reason: "Only SQL Databases Supported")) }

        let query: SQLQueryString = """
        SELECT
            COALESCE(
                SUM(
                    CASE status
                    WHEN 0::char THEN
                        1
                    ELSE
                        0
                    END
                )
            , 0) as "queuedCount",
            COALESCE(
                SUM(
                    CASE status
                    WHEN 1::char THEN
                        1
                    ELSE
                        0
                    END
                )
            , 0) as "runningCount"
        FROM
            _queue_job_completions
        """

        return sqlDb.raw(query).first(decoding: CurrentJobsStatusResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
    }

    /// Retrieves data about jobs that ran successfully over the specified time period
    /// - Parameters:
    ///   - db: The Database to run the query on - must be a `SQLDatabase`
    ///   - hours: The number of previous hours to check (i.e. if `1` is specified, it will retrieve data for the past 1 hour)
    /// - Returns: The data returned from the query
    static func getCompletedJobsForTimePeriod(db: Database, hours: Int) -> EventLoopFuture<CompletedJobStatusResponse> {
        guard let sqlDb = db as? SQLDatabase else { return db.eventLoop.future(error: Abort(.badRequest, reason: "Only SQL Databases Supported")) }

        let query: SQLQueryString = """
        SELECT
            COUNT(*) as "completedJobs",
            COALESCE(SUM(
                CASE status
                WHEN 2::char THEN
                    1
                ELSE
                    0
                END) / count(*), 1) as "percentSuccess"
        FROM
            _queue_job_completions
        WHERE
            "completedAt" IS NOT NULL
            AND "completedAt" >= (NOW() - '\(raw: "\(hours)") HOURS'::INTERVAL)
        """

        return sqlDb.raw(query).first(decoding: CompletedJobStatusResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
    }

    /// Retrieves data about the how quickly jobs ran and how long they waited to be run
    /// - Parameters:
    ///   - db: The Database to run the query on - must be a `SQLDatabase`
    ///   - hours: The number of previous hours to check (i.e. if `1` is specified, it will retrieve data for the past 1 hour)
    ///   - jobName: The name of the job to filter on, if any
    /// - Returns: The data returned from the query
    static func getTimingDataForJobs(db: Database, hours: Int, jobName: String? = nil) -> EventLoopFuture<JobsTimingResponse> {
        guard let sqlDb = db as? SQLDatabase else { return db.eventLoop.future(error: Abort(.badRequest, reason: "Only SQL Databases Supported")) }

        let jobFilterString: SQLQueryString
        if let jobName = jobName {
            jobFilterString = "AND \"jobName\" = \(raw: jobName)"
        } else {
            jobFilterString = ""
        }

        let query: SQLQueryString = """
        SELECT
            avg(EXTRACT(EPOCH FROM ("dequeuedAt" - "completedAt"))) as "avgRunTime",
            avg(EXTRACT(EPOCH FROM ("queuedAt" - "dequeuedAt"))) as "avgWaitTime"
        FROM
            _queue_job_completions
        WHERE
            "completedAt" IS NOT NULL
            AND "dequeuedAt" is not null
            AND "completedAt" >= (NOW() - '\(raw: "\(hours)") HOURS'::INTERVAL)
            \(jobFilterString)
        """

        return sqlDb.raw(query).first(decoding: JobsTimingResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
    }
}

/// Data about jobs currently queued or running
public struct CurrentJobsStatusResponse: Content {
    /// The number of queueud jobs currently waiting to be run
    public let queuedCount: Int

    /// The number of jobs currently running
    public let runningCount: Int
}

/// Data about jobs that have run successfully over a time period
public struct CompletedJobStatusResponse: Content {
    /// The number of jobs that completed successfully
    public let completedJobs: Int

    /// The percent of jobs (out of all jobs run in the time period) that ran successfully
    public let percentSuccess: Double
}

/// Data about how long jobs are taking to run
public struct JobsTimingResponse: Content {

    /// The average time spent running a job
    public let avgRunTime: Double?

    /// The average time jobs spent waiting to be processed
    public let avgWaitTime: Double?
}

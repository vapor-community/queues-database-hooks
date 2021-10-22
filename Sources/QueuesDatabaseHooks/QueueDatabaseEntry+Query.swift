import Foundation
import FluentKit
import SQLKit
import Vapor

public extension QueueDatabaseEntry {

    /// Returns the current counts of queued and running jobs.
    /// - Parameters:
    ///   - db: The Database to run the query on.
    /// - Returns: A future whose result is a structure containing the counts of queued and running jobs at the time of
    ///   the query.
    static func getStatusOfCurrentJobs(db: Database) -> EventLoopFuture<CurrentJobsStatusResponse> {
        if let sql = db as? SQLDatabase {
            /// This syntax is compatible with all supported SQL databases at the time of this writing.
            return sql.raw("""
                SELECT
                    COALESCE(SUM(IF(\(ident: "status")=\(literal: 0),\(literal: 1),\(literal: 0))),\(literal: 0)) AS \(ident: "queuedCount"),
                    COALESCE(SUM(IF(\(ident: "status")=\(literal: 1),\(literal: 1),\(literal: 0))),\(literal: 0)) AS \(ident: "runningCount")
                FROM
                    \(ident: QueueDatabaseEntry.schema)
                """)
            .first(decoding: CurrentJobsStatusResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
        } else {
            return QueueDatabaseEntry.query(on: db).filter(\.$status == .queued).count(\.$id).flatMap { queuedCount in
                QueueDatabaseEntry.query(on: db).filter(\.$status == .running).count(\.$id).map { runningCount in
                    .init(queuedCount: queuedCount, runningCount: runningCount)
                }
            }
        }
    }

    /// Retrieves data about jobs that ran successfully over the specified time period.
    ///
    /// - Parameters:
    ///   - db: The Database to run the query on.
    ///   - hours: The maximum age in hours for a job to be considered. For example, a value of `1` will retrieve data
    ///     only for jobs whose completion date is within the past hour. Negative numbers and `0` are illegal inputs.
    /// - Returns: A future whose result is a structure containing the count of completed jobs and the percentage of
    ///   those jobs which completed successfully within the past given number of hours, as of the time of the query.
    static func getCompletedJobsForTimePeriod(db: Database, hours: Int) -> EventLoopFuture<CompletedJobStatusResponse> {
        precondition(hours > 0, "Can not request job data for jobs in the future.")
        
        let deadline = Calendar.current.date(byAdding: .hour, value: -hours, to: Date(), wrappingComponents: true)

        if let sql = db as? SQLDatabase {
            return sql.raw("""
                SELECT
                    COUNT(\(ident: "id")) AS \(ident: "completedJobs"),
                    COALESCE(SUM(IF(\(ident: "status")=\(literal: 2),\(literal: 1),\(literal: 0))) / COUNT(\(ident: "id")),\(literal: 1))
                        AS \(ident: "percentSuccess")
                FROM
                    \(ident: QueueDatabaseEntry.schema)
                WHERE
                    \(ident: "completedAt")>=\(bind: deadline)
                """)
            .first(decoding: CompletedJobStatusResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
        } else {
            return QueueDatabaseEntry.query(on: db).filter(\.$completedAt >= deadline).count(\.$id).flatMap { completedJobs in
                QueueDatabaseEntry.query(on: db).filter(\.$completedAt >= deadline).filter(\.$status == .success).count(\.$id).map { successfulJobs in
                    .init(completedJobs: completedJobs, percentSuccess: Double(successfulJobs) / Double(completedJobs))
                }
            }
        }
    }

    /// Retrieves data about the how quickly jobs ran and how long they waited to be run.
    ///
    /// - Warning: At the time of this writing, due to limitations of Fluent, this query may run _very_ slowly if used
    ///   with a NoSQL database driver like Mongo, depending on the number of jobs recorded in the database and the
    ///   given filtering parameters.
    ///
    /// - Parameters:
    ///   - db: The Database to run the query on.
    ///   - hours: The maximum age in hours for a job to be considered. For example, a value of `1` will retrieve data
    ///     only for jobs whose completion date is within the past hour. Negative numbers and `0` are illegal inputs.
    ///   - jobName: The name of the job to filter on, if any
    /// - Returns: A future whose result is a structure containing the average number of seconds it took the specified
    ///   jobs to run and that the specified jobs spent queued before running within the past given number of hours, as
    ///   of the time of the query.
    static func getTimingDataForJobs(db: Database, hours: Int, jobName: String? = nil) -> EventLoopFuture<JobsTimingResponse> {
        precondition(hours > 0, "Can not request job data for jobs in the future.")
        
        let deadline = Calendar.current.date(byAdding: .hour, value: -hours, to: Date(), wrappingComponents: true)

        if let sql = db as? SQLDatabase {
            let jobNameClause: SQLQueryString = jobName.map { "\(ident: "jobName")=\(bind: $0)" } ?? "\(literal: 1)=\(literal: 1)"
            let dateDiffExpression: (String, String) -> SQLQueryString
            switch sql.dialect.name {
                case "mysql":      dateDiffExpression = { "TIMESTAMPDIFF(SECOND, \(ident: $1), \(ident: $0))" }
                case "postgresql": dateDiffExpression = { "extract(epoch from \(ident: $0) - \(ident: $1))" }
                case "sqlite":     dateDiffExpression = { "strftime(\(literal: "%s"), \(ident: $0)) - strftime(\(literal: "%s"), \(ident: $1))" }
                case let name:
                    /// Because people are stubborn, only crash in Debug.
                    assertionFailure("You're using an unsupported SQL dialect (\(name)), try again.")
                    return sql.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Unsupported SQL database dialect '\(name)'"))
            }
            
            return sql.raw("""
                SELECT
                    COALESCE(AVG(\(dateDiffExpression("completedAt", "dequeuedAt"))), \(literal: 0)) AS \(ident: "avgRunTime"),
                    COALESCE(AVG(\(dateDiffExpression("dequeuedAt", "queuedAt"))), \(literal: 0)) AS \(ident: "avgWaitTime")
                FROM
                    \(ident: QueueDatabaseEntry.schema)
                WHERE
                    \(ident: "dequeuedAt") IS NOT \(SQLLiteral.null) AND
                    \(ident: "completedAt")>=\(bind: deadline) AND
                    \(jobNameClause)
                """)
            .first(decoding: JobsTimingResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
        } else {
            return QueueDatabaseEntry.query(on: db)
                .field(\.$queuedAt).field(\.$dequeuedAt).field(\.$completedAt)
                .filter(\.$completedAt >= deadline)
                .filter(\.$dequeuedAt != nil)
                .filter(\.$jobName, .equality(inverse: jobName == nil), jobName ?? "")
                .all()
            .nonemptyMap(or: .init(avgRunTime: nil, avgWaitTime: nil)) {
                let sums = $0.reduce((0.0, 0.0)) { s, q in (
                    s.0 + (q.completedAt!.timeIntervalSinceReferenceDate - q.dequeuedAt!.timeIntervalSinceReferenceDate),
                    s.1 + (q.dequeuedAt!.timeIntervalSinceReferenceDate - q.queuedAt.timeIntervalSinceReferenceDate)
                ) }
                return .init(avgRunTime: sums.0 / Double($0.count), avgWaitTime: sums.1 / Double($0.count))
            }
        }
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

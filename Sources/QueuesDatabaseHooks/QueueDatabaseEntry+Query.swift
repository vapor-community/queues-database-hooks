import Foundation
import FluentKit
import FluentMySQLDriver
import FluentPostgresDriver
import SQLKit
import Vapor

public extension QueueDatabaseEntry {

    /// Returns the current queued count of jobs and current running count
    /// - Parameter db: The Database to run the query on - must be a `SQLDatabase`
    /// - Returns: The data returned from the query
    static func getStatusOfCurrentJobs(db: Database) -> EventLoopFuture<CurrentJobsStatusResponse> {
        guard let sqlDb = db as? SQLDatabase else { return db.eventLoop.future(error: Abort(.badRequest, reason: "Only SQL Databases Supported")) }

        //if sqlDb is PostgresDatabase {
        let query: SQLQueryString!
        if sqlDb is PostgresDatabase {
            query = PostgresSqlQuery.getStatusOfCurrentJobsQuery()
        } else if sqlDb is MySQLDatabase {
            query = MySqlQuery.getStatusOfCurrentJobsQuery()
        } else {
            return db.eventLoop.future(error: Abort(.badRequest, reason: "Only Postgres or MySql Databases Supported"))
        }
        return sqlDb.raw(query).first(decoding: CurrentJobsStatusResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
    }

    /// Retrieves data about jobs that ran successfully over the specified time period
    /// - Parameters:
    ///   - db: The Database to run the query on - must be a `SQLDatabase`
    ///   - hours: The number of previous hours to check (i.e. if `1` is specified, it will retrieve data for the past 1 hour)
    /// - Returns: The data returned from the query
    static func getCompletedJobsForTimePeriod(db: Database, hours: Int) -> EventLoopFuture<CompletedJobStatusResponse> {
        guard let sqlDb = db as? SQLDatabase else { return db.eventLoop.future(error: Abort(.badRequest, reason: "Only SQL Databases Supported")) }

        let query: SQLQueryString!
        if sqlDb is PostgresDatabase {
            query = PostgresSqlQuery.getCompletedJobsForTimePeriodQuery(hours: hours)
        } else if sqlDb is MySQLDatabase {
            query = MySqlQuery.getCompletedJobsForTimePeriodQuery(hours: hours)
        } else {
            return db.eventLoop.future(error: Abort(.badRequest, reason: "Only Postgres or MySql Databases Supported"))
        }
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

        let query: SQLQueryString!
        if sqlDb is PostgresDatabase {
            query = PostgresSqlQuery.getTimingDataForJobsQuery(hours: hours, jobName: jobName)
        } else if sqlDb is MySQLDatabase {
            query = MySqlQuery.getTimingDataForJobsQuery(hours: hours, jobName: jobName)
        } else {
            return db.eventLoop.future(error: Abort(.badRequest, reason: "Only Postgres or MySql Databases Supported"))
        }
        return sqlDb.raw(query).first(decoding: JobsTimingResponse.self).unwrap(or: Abort(.badRequest, reason: "Could not get data for status"))
    }
}

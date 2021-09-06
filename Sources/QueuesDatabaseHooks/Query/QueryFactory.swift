//
//  QueryFactory.swift
//  
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import FluentMySQLDriver
import FluentPostgresDriver

public class QueryFactory {
    enum QueryFactoryError: Error {
        case databaseNotSupported
    }

    internal static func getStatusOfCurrentJobsQuery(_ db: Database) throws -> SQLQueryString {
        switch db {
        case is PostgresDatabase: return PostgresSqlQuery.getStatusOfCurrentJobsQuery()
        case is MySQLDatabase: return MySqlQuery.getStatusOfCurrentJobsQuery()
        default: throw QueryFactoryError.databaseNotSupported
        }
    }

    internal static func getCompletedJobsForTimePeriodQuery(_ db: Database, hours: Int) throws -> SQLQueryString {
        switch db {
        case is PostgresDatabase: return PostgresSqlQuery.getCompletedJobsForTimePeriodQuery(hours: hours)
        case is MySQLDatabase: return MySqlQuery.getCompletedJobsForTimePeriodQuery(hours: hours)
        default: throw QueryFactoryError.databaseNotSupported
        }
    }

    internal static func getTimingDataForJobsQuery(_ db: Database, hours: Int, jobName: String? = nil) throws -> SQLQueryString {
        switch db {
        case is PostgresDatabase: return PostgresSqlQuery.getTimingDataForJobsQuery(hours: hours, jobName: jobName)
        case is MySQLDatabase: return MySqlQuery.getTimingDataForJobsQuery(hours: hours, jobName: jobName)
        default: throw QueryFactoryError.databaseNotSupported
        }
    }
}

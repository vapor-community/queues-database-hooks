//
//  PostgresSqlQuery.swift
//  
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import FluentKit
import SQLKit
import Vapor

public class PostgresSqlQuery {
    internal static func getStatusOfCurrentJobsQuery() -> SQLQueryString {
        """
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
    }

    internal static func getCompletedJobsForTimePeriodQuery(hours: Int) -> SQLQueryString {
        """
        SELECT
            COUNT(*) as "completedJobs",
            COALESCE(SUM(
                CASE status
                WHEN 2::char THEN
                    1
                ELSE
                    0
                END) / count(*), 1)::FLOAT as "percentSuccess"
        FROM
            _queue_job_completions
        WHERE
            "completedAt" IS NOT NULL
            AND "completedAt" >= (NOW() - '\(raw: "\(hours)") HOURS'::INTERVAL)
        """
    }

    internal static func getTimingDataForJobsQuery(hours: Int, jobName: String? = nil) -> SQLQueryString {
        let jobFilterString: SQLQueryString
        if let jobName = jobName {
            jobFilterString = "AND \"jobName\" = \(raw: jobName)"
        } else {
            jobFilterString = ""
        }

        return """
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
    }
}

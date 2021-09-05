//
//  MySqlQuery.swift
//  
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import FluentKit
import SQLKit
import Vapor

public class MySqlQuery {
    internal static func getStatusOfCurrentJobsQuery() -> SQLQueryString {
        """
        SELECT
            COALESCE(
                SUM(
                    CASE status
                    WHEN 0 THEN
                        1
                    ELSE
                        0
                    END
                )
            , 0) as "queuedCount",
            COALESCE(
                SUM(
                    CASE status
                    WHEN 1 THEN
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
                WHEN 2 THEN
                    1
                ELSE
                    0
                END) / count(*), 1) as "percentSuccess"
        FROM
            _queue_job_completions
        WHERE
            completedAt IS NOT NULL
            AND completedAt >= DATE_SUB(now(), interval \(raw: "\(hours)") hour)
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
            avg(TIMESTAMPDIFF(second, dequeuedAt, completedAt)) as "avgRunTime",
            avg(TIMESTAMPDIFF(second, queuedAt, dequeuedAt)) as "avgWaitTime"
        FROM
            _queue_job_completions
        WHERE
            completedAt IS NOT NULL
            AND dequeuedAt is not null
            AND completedAt >= DATE_SUB(now(), interval \(raw: "\(hours)") hour)
            \(jobFilterString)
        """
    }
}

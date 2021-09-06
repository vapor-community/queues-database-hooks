//
//  CompletedJobStatusResponse.swift
//
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import Vapor

/// Data about jobs that have run successfully over a time period
public struct CompletedJobStatusResponse: Content {
    /// The number of jobs that completed successfully
    public let completedJobs: Int

    /// The percent of jobs (out of all jobs run in the time period) that ran successfully
    public let percentSuccess: Double
}

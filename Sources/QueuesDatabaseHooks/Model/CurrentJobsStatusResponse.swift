//
//  CurrentJobsStatusResponse.swift
//
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import Vapor

/// Data about jobs currently queued or running
public struct CurrentJobsStatusResponse: Content {
    /// The number of queueud jobs currently waiting to be run
    public let queuedCount: Int

    /// The number of jobs currently running
    public let runningCount: Int
}

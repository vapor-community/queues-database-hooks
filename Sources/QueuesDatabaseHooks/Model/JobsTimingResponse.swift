//
//  JobsTimingResponse.swift
//  
//
//  Created by lgriffie on 05/09/2021.
//

import Foundation
import Vapor

/// Data about how long jobs are taking to run
public struct JobsTimingResponse: Content {
    /// The average time spent running a job
    public let avgRunTime: Double?

    /// The average time jobs spent waiting to be processed
    public let avgWaitTime: Double?
}

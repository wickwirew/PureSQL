//
//  DatabaseConfig.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

import Foundation

/// Holds any variables needed to configure a connection to a database
public struct DatabaseConfig {
    /// The location on disk, if `nil` it will be in memory
    public var path: String?
    /// The maximum number of connections allowed in the pool.
    /// In memory databases will be overriden to `1` regardless
    /// of the input
    public var maxConnectionCount: Int

    public init(
        path: String?,
        maxConnectionCount: Int = 5
    ) {
        self.path = path
        self.maxConnectionCount = maxConnectionCount
    }
}

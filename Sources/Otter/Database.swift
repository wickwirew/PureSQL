//
//  Database.swift
//  Otter
//
//  Created by Wes Wickwire on 5/4/25.
//

import Foundation

/// The base protocol every generated database conforms too.
public protocol Database: ConnectionWrapper {
    /// The connection to use
    init(connection: any Connection)
    /// An ordered list of migrations to be run.
    static var migrations: [String] { get }
}

public extension Database {
    /// Opens a connection pool to the database at the given URL.
    ///
    /// - Parameter url: The url of the database file
    init(url: URL) throws {
        self = try Self(path: url.path)
    }

    /// Opens a connection pool to the database at the given path.
    ///
    /// - Parameter path: The path of the database file
    init(path: String) throws {
        self = try Self(config: DatabaseConfig(path: path))
    }

    /// Opens a connection pool to the database
    ///
    /// - Parameter config: The configuration specifying any info
    /// needed to open the database.
    init(config: DatabaseConfig) throws {
        let connection: any Connection = if let path = config.path {
            try ConnectionPool(
                path: path,
                limit: config.maxConnectionCount,
                migrations: Self.migrations
            )
        } else {
            try ConnectionPool(
                path: ":memory:",
                limit: 1,
                migrations: Self.migrations
            )
        }

        self = Self(connection: connection)
    }

    /// Creates an in memory database.
    static func inMemory() throws -> Self {
        return try Self(config: DatabaseConfig(path: nil))
    }
}

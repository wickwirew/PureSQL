//
//  Database.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/4/25.
//

import Foundation

/// The base protocol every generated database conforms too.
public protocol Database: ConnectionWrapper {
    associatedtype Adapters
    
    /// The connection to use
    init(connection: any Connection, adapters: Adapters)
    /// An ordered list of migrations to be run.
    static var migrations: [String] { get }
    /// The `migrations` sanitized with all non-valid SQL removed.
    ///
    /// Note: This only exists for the @Database macro. The macro will
    /// generate this. Not needed for the build tool plugin
    static var sanitizedMigrations: [String] { get }
}

public extension Database {
    static var sanitizedMigrations: [String] { migrations }
    
    /// Opens a connection pool to the database at the given URL.
    ///
    /// - Parameter url: The url of the database file
    init(url: URL, adapters: Adapters) throws {
        self = try Self(path: url.path, adapters: adapters)
    }

    /// Opens a connection pool to the database at the given path.
    ///
    /// - Parameter path: The path of the database file
    init(path: String, adapters: Adapters) throws {
        self = try Self(config: DatabaseConfig(path: path), adapters: adapters)
    }

    /// Opens a connection pool to the database
    ///
    /// - Parameter config: The configuration specifying any info
    /// needed to open the database.
    init(config: DatabaseConfig, adapters: Adapters) throws {
        let connection: any Connection = if let path = config.path {
            try ConnectionPool(
                path: path,
                limit: config.maxConnectionCount,
                migrations: Self.sanitizedMigrations,
                runMigrations: config.autoMigrate
            )
        } else {
            try ConnectionPool(
                path: ":memory:",
                limit: 1,
                migrations: Self.sanitizedMigrations,
                runMigrations: config.autoMigrate
            )
        }

        self = Self(connection: connection, adapters: adapters)
    }

    /// Creates an in memory database.
    static func inMemory(adapters: Adapters) throws -> Self {
        return try Self(config: DatabaseConfig(path: nil), adapters: adapters)
    }
    
    /// Runs the migrations up to and including the `maxMigration`.
    func migrate(upTo maxMigration: Int? = nil) async throws {
        try await connection.withConnection(isWrite: true) { conn in
            try MigrationRunner.execute(
                migrations: Self.sanitizedMigrations,
                connection: conn,
                upTo: maxMigration
            )
        }
    }
}


extension Database where Adapters == DefaultAdapters {
    /// Opens a connection pool to the database at the given URL.
    ///
    /// - Parameter url: The url of the database file
    init(url: URL) throws {
        self = try Self(url: url, adapters: DefaultAdapters())
    }

    /// Opens a connection pool to the database at the given path.
    ///
    /// - Parameter path: The path of the database file
    init(path: String) throws {
        self = try Self(path: path, adapters: DefaultAdapters())
    }

    /// Opens a connection pool to the database
    ///
    /// - Parameter config: The configuration specifying any info
    /// needed to open the database.
    init(config: DatabaseConfig) throws {
        self = try Self(config: config, adapters: DefaultAdapters())
    }
    
    /// Creates an in memory database.
    public static func inMemory() throws -> Self {
        return try Self(config: DatabaseConfig(path: nil), adapters: DefaultAdapters())
    }
}

/// A marker protocol for the adapters for a database.
/// Need a protocol so we can do extensions on the Database.Adapters
public protocol Adapters: Sendable {}

/// The default type for adapters when the database is generated
/// if there are no adapters
public struct DefaultAdapters: Adapters {
    public init() {}
}

extension Adapters {
    public var bool: BoolDatabaseValueAdapter { BoolDatabaseValueAdapter() }
    public var int8: Int8DatabaseValueAdapter { Int8DatabaseValueAdapter() }
    public var int16: Int16DatabaseValueAdapter { Int16DatabaseValueAdapter() }
    public var int32: Int32DatabaseValueAdapter { Int32DatabaseValueAdapter() }
    public var int64: Int64DatabaseValueAdapter { Int64DatabaseValueAdapter() }
    public var uint8: UInt8DatabaseValueAdapter { UInt8DatabaseValueAdapter() }
    public var uint16: UInt16DatabaseValueAdapter { UInt16DatabaseValueAdapter() }
    public var uint32: UInt32DatabaseValueAdapter { UInt32DatabaseValueAdapter() }
    public var uint64: UInt64DatabaseValueAdapter { UInt64DatabaseValueAdapter() }
    public var uint: UIntDatabaseValueAdapter { UIntDatabaseValueAdapter() }
    public var float: FloatDatabaseValueAdapter { FloatDatabaseValueAdapter() }
    @available(macOS 11.0, *)
    @available(iOS 14.0, *)
    public var float16: Float16DatabaseValueAdapter { Float16DatabaseValueAdapter() }
    public var uuid: UUIDDatabaseValueAdapter { UUIDDatabaseValueAdapter() }
    public var decimal: DecimalDatabaseValueAdapter { DecimalDatabaseValueAdapter() }
    public var date: DateDatabaseValueAdapter { DateDatabaseValueAdapter() }
    public var url: URLDatabaseValueAdapter { URLDatabaseValueAdapter() }
}

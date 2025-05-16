//
//  Database.swift
//  Feather
//
//  Created by Wes Wickwire on 5/4/25.
//

public protocol Database {
    init(connection: any Connection)
    static var migrations: [String] { get }
    static var alwaysMigration: String? { get }
}

public extension Database {
    init(config: DatabaseConfig) throws {
        let connection: any Connection = if let path = config.path {
            try ConnectionPool(
                path: path,
                limit: config.maxConnectionCount,
                migrations: Self.migrations,
                alwaysMigration: Self.alwaysMigration
            )
        } else {
            try ConnectionPool(
                path: ":memory:",
                limit: 1,
                migrations: Self.migrations,
                alwaysMigration: Self.alwaysMigration
            )
        }
        
        self = Self(connection: connection)
    }
    
    static var alwaysMigration: String? { nil }
    
    static func inMemory() throws -> Self {
        return try Self(config: DatabaseConfig(path: nil))
    }
}

//
//  Language.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public protocol Language {
    associatedtype File
    associatedtype Query
    associatedtype Migration
    
    static func migration(
        source: String
    ) throws -> Migration
    
    static func query(
        source: String,
        statement: Statement,
        name: Substring
    ) throws -> Query
    
    static func file(migrations: [Migration], queries: [Query]) throws -> File
    
    static func string(for file: File) -> String
}

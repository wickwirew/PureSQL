//
//  Language.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public protocol Language {
    associatedtype Table
    associatedtype File
    associatedtype Query
    associatedtype Migration
    
    static func migration(
        source: String
    ) throws -> Migration
    
    static func table(name: Substring, columns: Columns) throws -> Table
    
    static func query(
        statement: Statement,
        name: Substring
    ) throws -> Query
    
    static func file(
        migrations: [Migration],
        tables: [Table],
        queries: [Query]
    ) throws -> File
    
    static func string(for file: File) -> String
}

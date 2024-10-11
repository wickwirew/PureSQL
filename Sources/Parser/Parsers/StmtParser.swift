//
//  StmtParser.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

import Schema

public struct StmtParser: Parser {
    public init() {}
    
    public func parse(state: inout ParserState) throws -> Statement {
        // This really needs more look ahead and actually
        // do the necessary logic to start the right parser
        return try .createTable(
            CreateTableParser()
                .parse(state: &state)
        )
    }
}

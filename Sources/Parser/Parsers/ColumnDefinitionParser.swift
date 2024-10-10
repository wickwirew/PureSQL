//
//  ColumnDefinitionParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import Schema

/// Parses a column definition that can be in a create table
/// or an alter statement.
///
/// https://www.sqlite.org/syntax/column-def.html
struct ColumnDefinitionParser: Parser {
    func parse(state: inout ParserState) throws -> ColumnDef {
        let name = try SymbolParser().parse(state: &state)
        let type = try TyParser().parse(state: &state)
        let constraints = try ColumnConstraintParser()
            .collect(until: [.comma, .closeParen])
            .parse(state: &state)
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
}

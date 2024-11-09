//
//  ColumnDefinitionParser.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

/// Parses a column definition that can be in a create table
/// or an alter statement.
///
/// https://www.sqlite.org/syntax/column-def.html
struct ColumnDefinitionParser: Parser {
    func parse(state: inout ParserState) throws -> ColumnDef {
        let name = try IdentifierParser().parse(state: &state)
        let type = try TypeNameParser().parse(state: &state)
        let constraints = try ColumnConstraintParser()
            .collect(until: [.comma, .closeParen, .eof, .semiColon])
            .parse(state: &state)
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
}

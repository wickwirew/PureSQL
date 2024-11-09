//
//  AlterTableParser.swift
//
//
//  Created by Wes Wickwire on 10/10/24.
//

struct AlterTableParser: Parser {
    func parse(state: inout ParserState) throws -> AlterTableStatement {
        try state.consume(.alter)
        try state.consume(.table)
        
        let (schema, table) = try TableAndSchemaNameParser()
            .parse(state: &state)
        
        let kind = try parseKind(state: &state)
        
        return AlterTableStatement(name: table, schemaName: schema, kind: kind)
    }
    
    private func parseKind(state: inout ParserState) throws -> AlterTableStatement.Kind {
        let token = try state.take()
        
        switch token.kind {
        case .rename:
            switch state.current.kind {
            case .to:
                try state.skip()
                
                let newName = try SymbolParser()
                    .parse(state: &state)
                
                return .rename(newName)
            default:
                _ = try state.take(if: .column)
                
                let symbol = SymbolParser()
                let oldName = try symbol.parse(state: &state)
                try state.consume(.to)
                let newName = try symbol.parse(state: &state)
                return .renameColumn(oldName, newName)
            }
        case .add:
            _ = try state.take(if: .column)
            let column = try ColumnDefinitionParser()
                .parse(state: &state)
            return .addColumn(column)
        case .drop:
            _ = try state.take(if: .column)
            let column = try SymbolParser()
                .parse(state: &state)
            return .dropColumn(column)
        default:
            throw ParsingError.expected(.rename, .add, .add, .drop, at: token.range)
        }
    }
}

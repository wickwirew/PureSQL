//
//  Parsers.swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//

enum Parsers {
    /// https://www.sqlite.org/lang_insert.html
    static func insertStmt(state: inout ParserState) throws -> InsertStmt {
        let start = state.current
        let cte = try withCte(state: &state)
        let action = try insertAction(state: &state)
        try state.consume(.into)
        let tableName = try tableName(state: &state)
        let alias = try take(if: .as, state: &state, parse: alias)
        let columns = try take(if: .openParen, state: &state, parse: columnNameList)
        let values = try insertValues(state: &state)
        let returningClause = try take(if: .returning, state: &state, parse: returningClause)
        
        return InsertStmt(
            cte: cte.cte,
            cteRecursive: cte.recursive,
            action: action,
            tableName: tableName,
            tableAlias: alias,
            columns: columns,
            values: values,
            returningClause: returningClause,
            range: state.range(from: start)
        )
    }
    
    static func insertValues(
        state: inout ParserState
    ) throws -> InsertStmt.Values? {
        if try state.take(if: .default) {
            try state.consume(.values)
            return nil
        } else {
            let select = try SelectStmtParser().parse(state: &state)
            let upsertClause = state.current.kind == .on ? try upsertClause(state: &state) : nil
            return .init(select: select, upsertClause: upsertClause)
        }
    }
    
    static func insertAction(
        state: inout ParserState
    ) throws -> InsertStmt.Action {
        let token = try state.take()
        
        return switch token.kind {
        case .replace: .replace
        case .insert: try .insert(take(if: .or, state: &state, parse: or))
        default:
            throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
        }
    }
    
    static func or(state: inout ParserState) throws -> Or {
        try state.consume(.or)
        let token = try state.take()
        switch token.kind {
        case .abort: return .abort
        case .fail: return .fail
        case .ignore: return .ignore
        case .replace: return .replace
        case .rollback: return .rollback
        default:
            throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
        }
    }
    
    /// https://www.sqlite.org/syntax/upsert-clause.html
    static func upsertClause(
        state: inout ParserState
    ) throws -> UpsertClause {
        let on = try state.take(.on)
        try state.consume(.conflict)
        
        let conflictTarget = try conflictTarget(state: &state)
        
        try state.consume(.do)
        
        if try state.take(if: .nothing) {
            return .init(
                confictTarget: conflictTarget,
                doAction: .nothing,
                range: on.range.lowerBound ..< state.current.range.lowerBound
            )
        }
        
        try state.consume(.update)
        try state.consume(.set)
        
        let sets = try delimited(by: .comma, state: &state, element: setAction)
        
        let whereExpr: Expression?
        if try state.take(if: .where) {
            whereExpr = try expr(state: &state)
        } else {
            whereExpr = nil
        }
        
        return UpsertClause(
            confictTarget: conflictTarget,
            doAction: .updateSet(sets: sets, where: whereExpr),
            range: on.range.lowerBound ..< state.current.range.lowerBound
        )
    }
    
    static func setAction(
        state: inout ParserState
    ) throws -> SetAction {
        let column: SetAction.Column
        if state.current.kind == .openParen {
            let columns = try parens(state: &state) { state in
                try delimited(by: .comma, state: &state, element: identifier)
            }
            
            column = .list(columns)
        } else {
            column = try .single(identifier(state: &state))
        }
        
        try state.consume(.equal)
        
        let expr = try ExprParser()
            .parse(state: &state)
        
        return SetAction(column: column, expr: expr)
    }
    
    static func conflictTarget(
        state: inout ParserState
    ) throws -> UpsertClause.ConflictTarget? {
        guard state.current.kind == .openParen else { return nil }
        
        let columns = try parens(state: &state) { state in
            try delimited(by: .comma, state: &state, element: indexedColumn)
        }
        
        let condition: Expression?
        if try state.take(if: .where) {
            condition = try expr(state: &state)
        } else {
            condition = nil
        }
        
        return UpsertClause.ConflictTarget(columns: columns, condition: condition)
    }
    
    /// https://www.sqlite.org/syntax/returning-clause.html
    static func returningClause(state: inout ParserState) throws -> ReturningClause {
        let start = try state.take(.returning)
        
        let values: [ReturningClause.Value] = try delimited(
            by: .comma,
            state: &state
        ) { state in
            if try state.take(if: .star) {
                return .all
            } else {
                let expr = try expr(state: &state)
                let alias = try take(if: .as, state: &state, parse: alias)
                return .expr(expr: expr, alias: alias)
            }
        }
        
        return ReturningClause(values: values, range: state.range(from: start))
    }
    
    static func updateStmt(state: inout ParserState) throws -> UpdateStmt {
        let start = state.range
        let cte = try withCte(state: &state)
        try state.consume(.update)
        let or = try take(if: .or, state: &state, parse: or)
        let tableName = try qualifiedTableName(state: &state)
        try state.consume(.set)
        let sets = try delimited(by: .comma, state: &state, element: setAction)
        let from = try from(state: &state)
        let whereExpr = try take(if: .where, state: &state) { state in
            try state.consume(.where)
            return try expr(state: &state)
        }
        let returningClause = try take(if: .returning, state: &state, parse: returningClause)
        return UpdateStmt(
            cte: cte.cte,
            cteRecursive: cte.recursive,
            or: or,
            tableName: tableName,
            sets: sets,
            from: from,
            whereExpr: whereExpr,
            returningClause: returningClause,
            range: state.range(from: start)
        )
    }
    
    static func qualifiedTableName(
        state: inout ParserState
    ) throws -> QualifiedTableName {
        let tableName = try tableName(state: &state)
        let alias = try take(if: .as, state: &state, parse: alias)
        
        let indexed: QualifiedTableName.Indexed?
        if try state.take(if: .indexed) {
            try state.consume(.by)
            indexed = try .by(identifier(state: &state))
        } else if try state.take(if: .not) {
            try state.consume(.indexed)
            indexed = .not
        } else {
            indexed = nil
        }
        
        return QualifiedTableName(
            tableName: tableName,
            alias: alias,
            indexed: indexed,
            range: state.range(from: tableName.range)
        )
    }
    
    /// https://www.sqlite.org/syntax/indexed-column.html
    static func indexedColumn(
        state: inout ParserState
    ) throws -> IndexedColumn {
        let expr = try expr(state: &state)
        
        let collation: IdentifierSyntax?
        if try state.take(if: .collate) {
            collation = try identifier(state: &state)
        } else {
            collation = nil
        }
        
        let order = try OrderParser().parse(state: &state)
        return IndexedColumn(expr: expr, collation: collation, order: order)
    }
    
    static func withCte(
        state: inout ParserState
    ) throws -> (cte: CommonTableExpression?, recursive: Bool) {
        if try state.take(if: .with) {
            let cteRecursive = try state.take(if: .recursive)
            return (try cte(state: &state), cteRecursive)
        } else {
            return (nil, false)
        }
    }
    
    /// https://www.sqlite.org/syntax/common-table-expression.html
    static func cte(
        state: inout ParserState
    ) throws -> CommonTableExpression {
        return try CommonTableExprParser().parse(state: &state)
    }
    
    static func from(state: inout ParserState) throws -> From? {
        let output = try JoinClauseOrTableOrSubqueryParser()
            .take(if: .from, consume: true)
            .parse(state: &state)
        
        return switch output {
        case .join(let joinClause): .join(joinClause)
        case .tableOrSubqueries(let tableOrSubqueries): .tableOrSubqueries(tableOrSubqueries)
        case nil: nil
        }
    }
    
    /// https://www.sqlite.org/syntax/column-name-list.html
    static func columnNameList(state: inout ParserState) throws -> [IdentifierSyntax] {
        return try parens(state: &state) { state in
            try delimited(by: .comma, state: &state, element: identifier)
        }
    }
    
    static func tableName(state: inout ParserState) throws -> TableName {
        let first = try identifier(state: &state)
        if try state.take(if: .dot) {
            return TableName(schema: first, name: try identifier(state: &state))
        } else {
            return TableName(schema: nil, name: first)
        }
    }
    
    static func alias(state: inout ParserState) throws -> IdentifierSyntax {
        try state.consume(.as)
        return try identifier(state: &state)
    }
    
    static func expr(state: inout ParserState) throws -> Expression {
        return try ExprParser().parse(state: &state)
    }
    
    static func take<Output>(
        if kind: Token.Kind,
        state: inout ParserState,
        parse: (inout ParserState) throws -> Output
    ) throws -> Output? {
        guard state.current.kind == kind else { return nil }
        return try parse(&state)
    }
    
    static func delimited<Element>(
        by kind: Token.Kind,
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) throws -> [Element] {
        var elements: [Element] = []
        
        repeat {
            try elements.append(element(&state))
        } while try state.take(if: kind)
        
        return elements
    }
    
    static func parens<Value>(
        state: inout ParserState,
        value: (inout ParserState) throws -> Value
    ) throws -> Value {
        try state.consume(.openParen)
        let value = try value(&state)
        try state.consume(.closeParen)
        return value
    }
    
    static func identifier(
        state: inout ParserState
    ) throws -> IdentifierSyntax {
        let token = try state.take()
        
        guard case let .symbol(ident) = token.kind else {
            state.diagnostics.add(.init("Expected identifier", at: token.range))
            return IdentifierSyntax(value: "<<error>>", range: token.range)
        }
        
        return IdentifierSyntax(value: ident, range: token.range)
    }
}

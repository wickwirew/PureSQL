//
//  Parsers.swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//

import OrderedCollections

enum Parsers {
    static func parse<Output>(
        source: String,
        parser: (inout ParserState) throws -> Output
    ) throws -> Output {
        var state = try ParserState(Lexer(source: source))
        return try parser(&state)
    }
    
    static func parse(source: String) throws -> [any Statement] {
        var state = try ParserState(Lexer(source: source))
        return try stmts(state: &state)
    }
    
    static func stmts(state: inout ParserState) throws -> [any Statement] {
        return try delimited(by: .semiColon, state: &state, element: stmt)
    }
    
    static func stmt(state: inout ParserState) throws -> any Statement {
        switch (state.current.kind, state.peek.kind) {
        case (.create, .table):
            return try Parsers.createTableStmt(state: &state)
        case (.alter, .table):
            return try Parsers.alterStmt(state: &state)
        case (.select, _):
            return try Parsers.selectStmt(state: &state)
        case (.semiColon, _), (.eof, _):
            try state.skip()
            return EmptyStatement()
        default:
            throw ParsingError.unexpectedToken(of: state.current.kind, at: state.current.range)
        }
    }
    
    static func insertStmt(state: inout ParserState) throws -> InsertStmt {
        let start = state.current
        let cte = try withCte(state: &state)
        return try insertStmt(
            state: &state,
            start: start,
            cteRecursive: cte.recursive,
            cte: cte.cte
        )
    }
    
    /// https://www.sqlite.org/lang_insert.html
    static func insertStmt(
        state: inout ParserState,
        start: Token,
        cteRecursive: Bool,
        cte: CommonTableExpression?
    ) throws -> InsertStmt {
        let action = try insertAction(state: &state)
        try state.consume(.into)
        let tableName = try tableName(state: &state)
        let alias = try maybeAlias(state: &state)
        let columns = try take(if: .openParen, state: &state, parse: columnNameList)
        let values = try insertValues(state: &state)
        let returningClause = try take(if: .returning, state: &state, parse: returningClause)
        
        return InsertStmt(
            cte: cte,
            cteRecursive: cteRecursive,
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
            let select = try selectStmt(state: &state)
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
        default: throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
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
        
        let expr = try Parsers.expr(state: &state)
        
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
                let alias = try maybeAlias(state: &state)
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
        let alias = try maybeAlias(state: &state)
        
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
        
        let order = try Parsers.order(state: &state)
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
        let table = try identifier(state: &state)
        
        let columns = try take(if: .openParen, state: &state) { state in
            try parens(state: &state) { state in
                try delimited(by: .comma, state: &state, element: identifier)
            }
        }

        try state.consume(.as)
        
        let materialized: Bool
        if try state.take(if: .not) {
            try state.consume(.materialized)
            materialized = false
        } else if try state.take(if: .materialized) {
            materialized = true
        } else {
            materialized = false
        }
        
        let select = try parens(state: &state, value: selectStmt)
        
        return CommonTableExpression(
            table: table,
            columns: columns ?? [],
            materialized: materialized,
            select: select
        )
    }
    
    static func joinConstraint(state: inout ParserState) throws -> JoinConstraint {
        if try state.take(if: .on) {
            return .on(
                try Parsers.expr(state: &state)
            )
        } else if try state.take(if: .using) {
            return .using(
                try parens(state: &state) { state in
                    try commaDelimited(state: &state, element: identifier)
                }
            )
        } else {
            return .none
        }
    }
    
    static func joinOperator(state: inout ParserState) throws -> JoinOperator {
        let token = try state.take()
        
        switch token.kind {
        case .comma: return .comma
        case .join: return .join
        case .natural:
            let token = try state.take()
            switch token.kind {
            case .join: return .natural
            case .left:
                if try state.take(if: .outer) {
                    try state.consume(.join)
                    return .left(natural: true, outer: true)
                } else {
                    try state.consume(.join)
                    return .left(natural: true)
                }
            case .right:
                try state.consume(.join)
                return .right(natural: true)
            case .inner:
                try state.consume(.join)
                return .inner(natural: true)
            case .full:
                try state.consume(.join)
                return .full(natural: true)
            default:
                throw ParsingError.expected(.left, .right, .inner, .join, at: state.current.range)
            }
        case .left:
            if try state.take(if: .outer) {
                try state.consume(.join)
                return .left(outer: true)
            } else {
                try state.consume(.join)
                return .left(outer: false)
            }
        case .right:
            try state.consume(.join)
            return .right()
        case .inner:
            try state.consume(.join)
            return .inner()
        case .cross:
            try state.consume(.join)
            return .cross
        case .full:
            try state.consume(.join)
            return .full()
        default:
            throw ParsingError(description: "Invalid join operator", sourceRange: state.current.range)
        }
    }
    
    static func from(state: inout ParserState) throws -> From? {
        let output = try take(if: .from, state: &state) { state in
            try state.consume(.from)
            return try joinClauseOrTableOrSubqueries(state: &state)
        }
        
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
        let names = try tableAndSchemaName(state: &state)
        return TableName(schema: names.schema, name: names.table)
    }
    
    static func tableAndSchemaName(state: inout ParserState) throws -> (schema: IdentifierSyntax?, table: IdentifierSyntax) {
        let first = try identifier(state: &state)
        if try state.take(if: .dot) {
            return (first, try identifier(state: &state))
        } else {
            return (nil, first)
        }
    }
    
    static func selectStmt(state: inout ParserState) throws -> SelectStmt {
        let start = state.current
        let cte = try withCte(state: &state)
        return try selectStmt(state: &state, start: start, cteRecursive: cte.recursive, cte: cte.cte)
    }
    
    static func selectStmt(
        state: inout ParserState,
        start: Token,
        cteRecursive: Bool,
        cte: CommonTableExpression?
    ) throws -> SelectStmt {
        let selects: [SelectCore]? = state.current.kind == .select || state.current.kind == .values
            ? try commaDelimited(state: &state, element: selectCore)
            : nil
        
        let orderBy = try orderingTerms(state: &state)
        let limit = try limit(state: &state)
        
        return SelectStmt(
            cte: cte,
            cteRecursive: cteRecursive,
            selects: .single(selects!.first!), // TODO: Fix this and do it properly
            orderBy: orderBy,
            limit: limit
        )
    }
    
    static func orderingTerms(state: inout ParserState) throws -> [OrderingTerm] {
        guard try state.take(if: .order) else { return [] }
        try state.consume(.by)
        return try commaDelimited(state: &state, element: orderingTerm)
    }
    
    static func limit(state: inout ParserState) throws -> SelectStmt.Limit? {
        guard try state.take(if: .limit) else { return nil }
        let first = try expr(state: &state)
        
        switch state.current.kind {
        case .comma:
            try state.skip()
            let second = try expr(state: &state)
            return SelectStmt.Limit(expr: second, offset: first)
        case .offset:
            try state.skip()
            let offset = try expr(state: &state)
            return SelectStmt.Limit(expr: first, offset: offset)
        default:
            return SelectStmt.Limit(expr: first, offset: nil)
        }
    }
    
    static func orderingTerm(state: inout ParserState) throws -> OrderingTerm {
        let expr = try expr(state: &state)
        
        let order: Order = if try state.take(if: .asc) {
            .asc
        } else if try state.take(if: .desc) {
            .desc
        } else {
            .asc
        }
        
        let nulls: OrderingTerm.Nulls? = if try state.take(if: .nulls) {
            if try state.take(if: .first) {
                .first
            } else if try state.take(if: .last) {
                .last
            } else {
                throw ParsingError.expected(.first, .last, at: state.range)
            }
        } else {
            nil
        }
        
        return OrderingTerm(expr: expr, order: order, nulls: nulls)
    }
    
    static func selectCore(state: inout ParserState) throws -> SelectCore {
        // Check if its values and to just get it out of the way
        if try state.take(if: .values) {
            return .values(
                try commaDelimitedInParens(state: &state) { try Parsers.expr(state: &$0) }
            )
        }
        
        try state.consume(.select)
        
        let distinct = if try state.take(if: .distinct) {
            true
        } else if try state.take(if: .all) {
            false
        } else {
            false
        }
        
        let columns = try commaDelimited(state: &state, element: resultColumn)
        
        let from = try from(state: &state)
        
        let `where` = try take(if: .where, state: &state) { state in
            try state.consume(.where)
            return try Parsers.expr(state: &state)
        }
        
        let groupBy = try groupBy(state: &state)
        
        let windows = try take(if: .window, state: &state) { state in
            try state.consume(.window)
            return try commaDelimited(state: &state, element: window)
        }
        
        let select = SelectCore.Select(
            distinct: distinct,
            columns: columns,
            from: from,
            where: `where`,
            groupBy: groupBy,
            windows: windows ?? []
        )
        
        return .select(select)
    }
    
    static func groupBy(state: inout ParserState) throws -> SelectCore.GroupBy? {
        guard try state.take(if: .group) else { return nil }
        try state.consume(.by)
        
        let exprs = try commaDelimited(state: &state) { try Parsers.expr(state: &$0) }
        
        let having = try take(if: .having, state: &state) { state in
            try state.consume(.having)
            return try Parsers.expr(state: &state)
        }
        
        return SelectCore.GroupBy(expressions: exprs, having: having)
    }
    
    static func window(state: inout ParserState) throws -> SelectCore.Window {
        let name = try identifier(state: &state)
        try state.consume(.as)
        let window = try windowDef(state: &state)
        return SelectCore.Window(name: name, window: window)
    }
    
    static func windowDef(state: inout ParserState) throws -> WindowDefinition {
        fatalError("TODO")
    }
    
    enum JoinClauseOrTableOrSubqueries: Equatable {
        case join(JoinClause)
        case tableOrSubqueries([TableOrSubquery])
    }
    
    /// This isnt necessarily a part of the grammar, but there is abiguity when starting
    /// a list of tables/subqueries or join clauses. Most likely the later but the the logic
    /// is duplicated in SQLites docs for the parsing so this just centralizes it.
    static func joinClauseOrTableOrSubqueries(
        state: inout ParserState
    ) throws -> JoinClauseOrTableOrSubqueries {
        // Both begin with a table or subquery
        let tableOrSubquery = try tableOrSubquery(state: &state)
        
        if state.current.kind == .comma {
            try state.skip()
            
            let more = try commaDelimited(state: &state, element: Self.tableOrSubquery)
            
            return .tableOrSubqueries([tableOrSubquery] + more)
        } else {
            // No comma, we are in join clause
            return .join(
                try joinClause(state: &state, tableOrSubquery: tableOrSubquery)
            )
        }
    }
    
    static func resultColumn(state: inout ParserState) throws -> ResultColumn {
        switch state.current.kind {
        case .star:
            try state.skip()
            return .all(table: nil)
        case .symbol(let table) where state.peek.kind == .dot && state.peek2.kind == .star:
            let table = IdentifierSyntax(value: table, range: state.current.range)
            try state.skip()
            try state.consume(.dot)
            try state.consume(.star)
            return .all(table: table)
        default:
            let expr = try expr(state: &state)
            
            if try state.take(if: .as) {
                let alias = try identifier(state: &state)
                return .expr(expr, as: alias)
            } else if case let .symbol(alias) = state.current.kind {
                let alias = IdentifierSyntax(value: alias, range: state.current.range)
                try state.skip()
                return .expr(expr, as: alias)
            } else {
                return .expr(expr, as: nil)
            }
        }
    }
    
    static func tableOrSubquery(state: inout ParserState) throws -> TableOrSubquery {
        switch state.current.kind {
        case .symbol:
            let (schema, table) = try tableAndSchemaName(state: &state)
            
            if state.current.kind == .openParen {
                let args = try commaDelimitedInParens(state: &state) { try expr(state: &$0) }
                let alias = try maybeAlias(state: &state, asRequired: false)
                return .tableFunction(schema: schema, table: table, args: args, alias: alias)
            } else {
                let alias = try maybeAlias(state: &state, asRequired: false)
                
                let indexedBy: IdentifierSyntax?
                switch state.current.kind {
                case .indexed:
                    try state.skip()
                    try state.consume(.by)
                    indexedBy = try identifier(state: &state)
                case .not:
                    try state.skip()
                    try state.consume(.indexed)
                    indexedBy = nil
                default:
                    indexedBy = nil
                }
                
                let table = TableOrSubquery.Table(
                    schema: schema,
                    name: table,
                    alias: alias,
                    indexedBy: indexedBy
                )
                
                return .table(table)
            }
        case .openParen:
            if state.peek.kind == .select {
                let subquery = try parens(state: &state, value: selectStmt)
                let alias = try maybeAlias(state: &state, asRequired: false)
                return .subquery(subquery, alias: alias)
            } else {
                let result = try parens(state: &state, value: joinClauseOrTableOrSubqueries)
                
                switch result {
                case .join(let joinClause):
                    return .join(joinClause)
                case .tableOrSubqueries(let table):
                    let alias = try maybeAlias(state: &state, asRequired: false)
                    return .subTableOrSubqueries(table, alias: alias)
                }
            }
        default:
            throw ParsingError(description: "Expected table or subquery", sourceRange: state.current.range)
        }
    }
    
    static func joinClause(
        state: inout ParserState,
        tableOrSubquery: TableOrSubquery
    ) throws -> JoinClause {
        let joinOperatorStarts: Set<Token.Kind> = [.natural, .comma, .left, .right, .full, .inner, .cross, .join]
        
        var joins: [JoinClause.Join] = []
        while joinOperatorStarts.contains(state.current.kind) {
            try joins.append(join(state: &state))
        }
        return JoinClause(tableOrSubquery: tableOrSubquery, joins: joins)
    }
    
    static func join(state: inout ParserState) throws -> JoinClause.Join {
        let op = try joinOperator(state: &state)
        
        let tableOrSubquery = try tableOrSubquery(state: &state)
        
        let constraint = try joinConstraint(state: &state)
        
        return JoinClause.Join(
            op: op,
            tableOrSubquery: tableOrSubquery,
            constraint: constraint
        )
    }
    
    /// Will try to parse out an alias
    /// e.g. `AS foo`.
    static func maybeAlias(
        state: inout ParserState,
        asRequired: Bool = true
    ) throws -> IdentifierSyntax? {
        if try state.take(if: .as) {
            return try identifier(state: &state)
        } else if !asRequired, case let .symbol(ident) = state.current.kind {
            let tok = try state.take()
            return IdentifierSyntax(value: ident, range: tok.range)
        } else {
            return nil
        }
    }
    
    /// https://www.sqlite.org/syntax/table-options.html
    static func tableOptions(state: inout ParserState) throws -> TableOptions {
        var options: TableOptions = []
        
        repeat {
            switch state.current.kind {
            case .without:
                try state.skip()
                try state.consume(.rowid)
                options = options.union(.withoutRowId)
            case .strict:
                try state.skip()
                options = options.union(.strict)
            case .eof, .semiColon:
                return options
            default:
                throw ParsingError.expected(.without, .strict, at: state.current.range)
            }
        } while try state.take(if: .comma)
        
        return options
    }
    
    /// https://www.sqlite.org/syntax/type-name.html
    static func typeName(state: inout ParserState) throws -> TypeName {
        var name = try identifier(state: &state)
        
        while case let .symbol(s) = state.current.kind {
            let upperBound = state.current.range.upperBound
            try state.skip()
            name.append(" \(s)", upperBound: upperBound)
        }
        
        if try state.take(if: .openParen) {
            let first = try signedNumber(state: &state)
            
            if try state.take(if: .comma) {
                let second = try signedNumber(state: &state)
                try state.consume(.closeParen)
                return TypeName(name: name, args: .two(first, second))
            } else {
                try state.consume(.closeParen)
                return TypeName(name: name, args: .one(first))
            }
        } else {
            return TypeName(name: name, args: nil)
        }
    }
    
    static func alterStmt(state: inout ParserState) throws -> AlterTableStatement {
        try state.consume(.alter)
        try state.consume(.table)
        let names = try tableAndSchemaName(state: &state)
        let kind = try alterKind(state: &state)
        return AlterTableStatement(name: names.table, schemaName: names.schema, kind: kind)
    }
    
    static func alterKind(state: inout ParserState) throws -> AlterTableStatement.Kind {
        let token = try state.take()
        
        switch token.kind {
        case .rename:
            switch state.current.kind {
            case .to:
                try state.skip()
                let newName = try identifier(state: &state)
                return .rename(newName)
            default:
                _ = try state.take(if: .column)
                let oldName = try identifier(state: &state)
                try state.consume(.to)
                let newName = try identifier(state: &state)
                return .renameColumn(oldName, newName)
            }
        case .add:
            _ = try state.take(if: .column)
            let column = try Parsers.columnDef(state: &state)
            return .addColumn(column)
        case .drop:
            _ = try state.take(if: .column)
            let column = try identifier(state: &state)
            return .dropColumn(column)
        default:
            throw ParsingError.expected(.rename, .add, .add, .drop, at: token.range)
        }
    }
    
    static func createTableStmt(state: inout ParserState) throws -> CreateTableStatement {
        try state.consume(.create)
        let isTemporary = try state.take(if: .temp, or: .temporary)
        try state.consume(.table)
        
        let ifNotExists = try state.take(if: .if)
        if ifNotExists {
            try state.consume(.not)
            try state.consume(.exists)
        }
        
        if state.is(of: .as) {
            fatalError("Implement SELECT statement")
        } else {
            let (schema, table) = try Parsers.tableAndSchemaName(state: &state)
            
            let columns: OrderedDictionary<IdentifierSyntax, ColumnDef> = try parens(state: &state) { state in
                try commaDelimited(state: &state, element: columnDef)
                    .reduce(into: [:], { $0[$1.name] = $1 })
            }
            
            let options = try Parsers.tableOptions(state: &state)
            
            return CreateTableStatement(
                name: table,
                schemaName: schema,
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .columns(columns),
                constraints: [],
                options: options
            )
        }
    }
    
    /// https://www.sqlite.org/syntax/column-def.html
    static func columnDef(state: inout ParserState) throws -> ColumnDef {
        let name = try identifier(state: &state)
        let type = try Parsers.typeName(state: &state)
        var constraints: [ColumnConstraint] = []
        
        while state.current.kind != .comma
             && state.current.kind != .closeParen
             && state.current.kind != .eof
             && state.current.kind != .semiColon
        {
            try constraints.append(columnConstraint(state: &state))
        }
        
        return ColumnDef(name: name, type: type, constraints: constraints)
    }
    
    static func columnConstraint(
        state: inout ParserState,
        name: IdentifierSyntax? = nil
    ) throws -> ColumnConstraint {
        switch state.current.kind {
        case .constraint:
            try state.skip()
            let name = try identifier(state: &state)
            return try columnConstraint(state: &state, name: name)
        case .primary:
            return try parsePrimaryKey(state: &state, name: name)
        case .not:
            try state.skip()
            try state.consume(.null)
            let conflictClause = try Parsers.conflictClause(state: &state)
            return ColumnConstraint(name: name, kind: .notNull(conflictClause))
        case .unique:
            try state.skip()
            let conflictClause = try Parsers.conflictClause(state: &state)
            return ColumnConstraint(name: name, kind: .unique(conflictClause))
        case .check:
            try state.skip()
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            return ColumnConstraint(name: name, kind: .check(expr))
        case .default:
            try state.skip()
            if state.current.kind == .openParen {
                let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
                return ColumnConstraint(name: name, kind: .default(expr))
            } else {
                let literal = try Parsers.literal(state: &state)
                return ColumnConstraint(name: name, kind: .default(.literal(literal)))
            }
        case .collate:
            try state.skip()
            let collation = try identifier(state: &state)
            return ColumnConstraint(name: name, kind: .collate(collation))
        case .references:
            let fk = try Parsers.foreignKeyClause(state: &state)
            return ColumnConstraint(name: name, kind: .foreignKey(fk))
        case .generated:
            try state.skip()
            try state.consume(.always)
            try state.consume(.as)
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            let generated = try parseGeneratedKind(state: &state)
            
            return ColumnConstraint(name: name, kind: .generated(expr, generated))
        case .as:
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            let generated = try parseGeneratedKind(state: &state)
            return ColumnConstraint(name: name, kind: .generated(expr, generated))
        default:
            throw ParsingError.unexpectedToken(of: state.current.kind, at: state.current.range)
        }
    }
    
    private static func parseGeneratedKind(
        state: inout ParserState
    ) throws -> ColumnConstraint.GeneratedKind? {
        return if try state.take(if: .stored) {
            .stored
        } else if try state.take(if: .virtual) {
            .virtual
        } else {
            nil
        }
    }
    
    private static func parsePrimaryKey(
        state: inout ParserState,
        name: IdentifierSyntax?
    ) throws -> ColumnConstraint {
        try state.consume(.primary)
        try state.consume(.key)
        let order = try Parsers.order(state: &state)
        let conflictClause = try Parsers.conflictClause(state: &state)
        let autoincrement = try state.take(if: .autoincrement)
        
        return ColumnConstraint(
            name: name,
            kind: .primaryKey(order: order, conflictClause, autoincrement: autoincrement)
        )
    }
    
    /// https://www.sqlite.org/syntax/conflict-clause.html
    static func conflictClause(state: inout ParserState) throws -> ConfictClause {
        guard state.current.kind == .on else { return .none }
        
        try state.consume(.on)
        try state.consume(.conflict)
        
        let token = try state.take()
        switch token.kind {
        case .rollback: return .rollback
        case .abort: return .abort
        case .fail: return .fail
        case .ignore: return .ignore
        case .replace: return .replace
        default: throw ParsingError.unexpectedToken(of: token.kind, at: token.range)
        }
    }
    
    static func foreignKeyClause(state: inout ParserState) throws -> ForeignKeyClause {
        try state.consume(.references)
        
        let table = try identifier(state: &state)
        
        let columns = try take(if: .openParen, state: &state) { state in
            try commaDelimitedInParens(state: &state, element: identifier)
        }
        
        let actions = try foreignKeyClauseActions(state: &state)
        
        return ForeignKeyClause(
            foreignTable: table,
            foreignColumns: columns ?? [],
            actions: actions
        )
    }
    
    static private func foreignKeyClauseActions(
        state: inout ParserState
    ) throws -> [ForeignKeyClause.Action] {
        guard let action = try foreignKeyClauseAction(state: &state) else { return [] }
        
        switch action {
        case .onDo, .match:
            return [action] + (try foreignKeyClauseActions(state: &state))
        case .deferrable, .notDeferrable:
            // These cannot have a secondary action
            return [action]
        }
    }
    
    static private func foreignKeyClauseAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Action? {
        switch state.current.kind {
        case .on:
            try state.skip()
            let on: ForeignKeyClause.On
            if try state.take(if: .delete) {
                on = .delete
            } else if try state.take(if: .update) {
                on = .update
            } else {
                state.diagnostics.add(.init("Expected 'UPDATE' or 'DELETE'", at: state.current.range))
                on = .update
            }
            
            return .onDo(on, try foreignKeyClauseOnDeleteOrUpdateAction(state: &state))
        case .match:
            try state.skip()
            let name = try identifier(state: &state)
            return .match(name, try foreignKeyClauseActions(state: &state))
        case .not:
            try state.skip()
            try state.consume(.deferrable)
            return .notDeferrable(try foreignKeyClauseDeferrable(state: &state))
        case .deferrable:
            try state.skip()
            return .deferrable(try foreignKeyClauseDeferrable(state: &state))
        default:
            return nil
        }
    }
    
    /// Parses out the action to be performed on an `ON` clause
    private static func foreignKeyClauseOnDeleteOrUpdateAction(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Do {
        let token = try state.take()
        
        switch token.kind {
        case .set:
            let token = try state.take()
            switch token.kind {
            case .null: return .setNull
            case .default: return .setDefault
            default: throw ParsingError.expected(.null, .default, at: token.range)
            }
        case .cascade:
            return .cascade
        case .restrict:
            return .restrict
        case .no:
            try state.consume(.action)
            return .noAction
        default: throw ParsingError.expected(.set, .cascade, .restrict, .no, at: token.range)
        }
    }
    
    private static func foreignKeyClauseDeferrable(
        state: inout ParserState
    ) throws -> ForeignKeyClause.Deferrable? {
        switch state.current.kind {
        case .initially:
            try state.skip()
            let token = try state.take()
            switch token.kind {
            case .deferred: return .initiallyDeferred
            case .immediate: return .initiallyImmediate
            default: throw ParsingError.expected(.deferred, .immediate, at: token.range)
            }
        default:
            return nil
        }
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func expr(
        state: inout ParserState,
        precedence: Operator.Precedence = 0
    ) throws -> Expression {
        var expr = try primaryExpr(state: &state, precedence: precedence)
        
        while true {
            // If the lhs was a column refernce with no table/schema and we are
            // at an open paren treat as a function call.
            if state.is(of: .openParen), case let .column(column) = expr, column.schema == nil {
                let args = try commaDelimitedInParens(state: &state) { try Parsers.expr(state: &$0) }
                return .fn(FunctionExpr(table: column.table, name: column.column, args: args, range: state.range(from: expr.range)))
            }
            
            guard let op = Operator.guess(for: state.current.kind, after: state.peek.kind),
                  op.precedence(usage: .infix) >= precedence else {
                return expr
            }
            
            // The between operator is a different one. It doesnt act like a
            // normal infix expression. There are two rhs expressions for the
            // lower and upper bounds. Those need to be parsed individually
            //
            // TODO: Move this to the Infix Parser
            if op == .between || op == .not(.between) {
                let op = try Parsers.operator(state: &state)
                assert(op.operator == .between || op.operator == .not(.between), "Guess cannot be wrong")
                
                // We need to dispatch the lower and upper bound expr's with a
                // precedence above AND so the AND is not included in the expr.
                // e.g. (a BETWEEN b AND C) not (a BETWEEN (b AND c))
                let precAboveAnd = Operator.and.precedence(usage: .infix) + 1
                let lowerBound = try Parsers.expr(state: &state, precedence: precAboveAnd)
                try state.consume(.and)
                let upperBound = try Parsers.expr(state: &state, precedence: precAboveAnd)
                expr = .between(BetweenExpr(not: op.operator == .not(.between), value: expr, lower: lowerBound, upper: upperBound))
            } else {
                expr = try infixExpr(state: &state, lhs: expr)
            }
        }
        
        return expr
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func primaryExpr(
        state: inout ParserState,
        precedence: Operator.Precedence
    ) throws -> Expression {
        switch state.current.kind {
        case .double, .string, .int, .hex, .currentDate, .currentTime, .currentTimestamp, .true, .false:
            return .literal(try Parsers.literal(state: &state))
        case .symbol:
            let column = try Parsers.columnExpr(state: &state)
            return .column(column)
        case .questionMark, .colon, .dollarSign, .at:
            return try .bindParameter(Parsers.bindParameter(state: &state))
        case .plus:
            let token = try state.take()
            let op = OperatorSyntax(operator: .plus, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .tilde:
            let token = try state.take()
            let op = OperatorSyntax(operator: .tilde, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .minus:
            let token = try state.take()
            let op = OperatorSyntax(operator: .minus, range: token.range)
            return try .prefix(PrefixExpr(operator: op, rhs: Parsers.expr(state: &state, precedence: precedence)))
        case .null:
            let token = try state.take()
            return .literal(LiteralExpr(kind: .null, range: token.range))
        case .openParen:
            let start = state.current.range
            let expr = try Parsers.parens(state: &state) { state in
                try Parsers.commaDelimited(state: &state) { try Parsers.expr(state: &$0) }
            }
            return .grouped(GroupedExpr(exprs: expr, range: state.range(from: start)))
        case .cast:
            let start = try state.take()
            try state.consume(.openParen)
            let expr = try Parsers.expr(state: &state)
            try state.consume(.as)
            let type = try Parsers.typeName(state: &state)
            try state.consume(.closeParen)
            return .cast(CastExpr(expr: expr, ty: type, range: state.range(from: start.range)))
        case .select:
            fatalError("TODO: Not yet implemented")
        case .exists:
            fatalError("TODO: Do when select is done")
        case .case:
            let start = try state.take()
            let `case` = try Parsers.take(ifNot: .when, state: &state) { try Parsers.expr(state: &$0) }
            
            var whenThens: [CaseWhenThenExpr.WhenThen] = []
            while state.current.kind == .when {
                try whenThens.append(Parsers.whenThen(state: &state))
            }
            
            let el: Expression? = if try state.take(if: .else) {
                try Parsers.expr(state: &state)
            } else {
                nil
            }
            
            try state.consume(.end)
            
            return .caseWhenThen(.init(case: `case`, whenThen: whenThens, else: el, range: state.range(from: start.range)))
        default:
            throw ParsingError(description: "Expected Expression", sourceRange: state.range)
        }
    }
    
    static func infixExpr(
        state: inout ParserState,
        lhs: Expression
    ) throws -> Expression {
        let op = try Parsers.operator(state: &state)
        
        switch op.operator {
        case .isnull, .notnull, .notNull, .collate:
            return .postfix(PostfixExpr(lhs: lhs, operator: op))
        default: break
        }
        
        let rhs = try Parsers.expr(
            state: &state,
            precedence: op.operator.precedence(usage: .infix) + 1
        )
        
        return .infix(InfixExpr(lhs: lhs, operator: op, rhs: rhs))
    }
    
    static func columnExpr(state: inout ParserState) throws -> ColumnExpr {
        let first = try identifier(state: &state)
        
        if try state.take(if: .dot) {
            let second = try identifier(state: &state)
            
            if try state.take(if: .dot) {
                return ColumnExpr(schema: first, table: second, column: try identifier(state: &state))
            } else {
                return ColumnExpr(schema: nil, table: first, column: second)
            }
        } else {
            return ColumnExpr(schema: nil, table: nil, column: first)
        }
    }
    
    static func whenThen(state: inout ParserState) throws -> CaseWhenThenExpr.WhenThen {
        try state.consume(.when)
        let when = try Parsers.expr(state: &state)
        try state.consume(.then)
        let then = try Parsers.expr(state: &state)
        return CaseWhenThenExpr.WhenThen(when: when, then: then)
    }
    
    /// https://www.sqlite.org/c3ref/bind_blob.html
    static func bindParameter(state: inout ParserState) throws -> BindParameter {
        let token = try state.take()
        
        switch token.kind {
        case .questionMark:
            return BindParameter(kind: .unnamed(state.nextParameterIndex()), range: token.range)
        case .colon:
            let symbol = try identifier(state: &state)
            let range = token.range.lowerBound..<symbol.range.upperBound
            return BindParameter(kind: .named(.init(value: ":\(symbol)", range: range)), range: range)
        case .at:
            let symbol = try identifier(state: &state)
            let range = token.range.lowerBound..<symbol.range.upperBound
            return BindParameter(kind: .named(.init(value: "@\(symbol)", range: range)), range: range)
        case .dollarSign:
            let segments = try delimited(by: .colon, and: .colon, state: &state, element: identifier)
            let nameRange = token.range.lowerBound..<(segments.last?.range.upperBound ?? state.current.range.upperBound)
            let fullName = segments.map(\.value)
                .joined(separator: "::")[...]
            let suffix = try take(if: .openParen, state: &state) { state in
                try parens(state: &state, value: identifier)
            }
            
            if let suffix {
                let range = token.range.lowerBound..<suffix.range.upperBound
                let ident = IdentifierSyntax(value: "$\(fullName)(\(suffix))", range: range)
                return BindParameter(kind: .named(ident), range: range)
            } else {
                let ident = IdentifierSyntax(value: "$\(fullName)", range: nameRange)
                return BindParameter(kind: .named(ident), range: nameRange)
            }
        default:
            throw ParsingError(description: "Invalid bind parameter", sourceRange: token.range)
        }
    }
    
    static func `operator`(state: inout ParserState) throws -> OperatorSyntax {
        guard let op = Operator.guess(
            for: state.current.kind,
            after: state.peek.kind
        ) else {
            throw ParsingError(description: "Invalid operator", sourceRange: state.range)
        }
        
        let start = state.current.range
        try op.skip(state: &state)
        
        switch op {
        case .tilde, .collate, .concat, .arrow, .doubleArrow, .multiply, .divide,
             .mod, .plus, .minus, .bitwiseAnd, .bitwuseOr, .shl, .shr, .escape,
             .lt, .gt, .lte, .gte, .eq, .eq2, .neq, .neq2, .match, .like, .regexp,
             .glob, .or, .and, .between, .not, .in, .isnull, .notnull, .notNull, .isDistinctFrom:
            return OperatorSyntax(operator: op, range: start)
        case .`is`:
            if try state.take(if: .distinct) {
                let from = try state.take(.from)
                return OperatorSyntax(operator: .isDistinctFrom, range: start.lowerBound..<from.range.upperBound)
            } else {
                return OperatorSyntax(operator: .is, range: start)
            }
        case .isNot:
            if try state.take(if: .distinct) {
                let from = try state.take(.from)
                return OperatorSyntax(operator: .isNotDistinctFrom, range: start.lowerBound..<from.range.upperBound)
            } else {
                return OperatorSyntax(operator: .isNot, range: start.lowerBound..<state.current.range.upperBound)
            }
        case .isNotDistinctFrom:
            fatalError("guess will not return these since the look ahead is only 2")
        }
    }
    
    static func take<Output>(
        if kind: Token.Kind,
        state: inout ParserState,
        parse: (inout ParserState) throws -> Output
    ) throws -> Output? {
        guard state.current.kind == kind else { return nil }
        return try parse(&state)
    }
    
    static func take<Output>(
        ifNot kind: Token.Kind,
        state: inout ParserState,
        parse: (inout ParserState) throws -> Output
    ) throws -> Output? {
        guard state.current.kind != kind else { return nil }
        return try parse(&state)
    }
    
    static func commaDelimited<Element>(
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) throws -> [Element] {
        return try delimited(by: .comma, state: &state, element: element)
    }
    
    static func commaDelimitedInParens<Element>(
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) throws -> [Element] {
        return try parens(state: &state) { state in
            try commaDelimited(state: &state, element: element)
        }
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
    
    static func delimited<Element>(
        by kind: Token.Kind,
        and otherKind: Token.Kind,
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) throws -> [Element] {
        var elements: [Element] = []
        
        repeat {
            try elements.append(element(&state))
        } while try state.take(if: kind, and: otherKind)
        
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
    
    /// https://www.sqlite.org/syntax/numeric-literal.html
    static func numericLiteral(state: inout ParserState) throws -> Numeric {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        case .hex(let value):
            return Double(value)
        default:
            throw ParsingError.expectedNumeric(at: token.range)
        }
    }
    
    /// https://www.sqlite.org/syntax/signed-number.html
    static func signedNumber(state: inout ParserState) throws -> SignedNumber {
        let token = try state.take()
        
        switch token.kind {
        case .double(let value):
            return value
        case .int(let value):
            return SignedNumber(value)
        case .hex(let value):
            return SignedNumber(value)
        case .plus:
            return try Parsers.numericLiteral(state: &state)
        case .minus:
            return try -Parsers.numericLiteral(state: &state)
        default:
            throw ParsingError.expectedNumeric(at: token.range)
        }
    }
    
    static func literal(state: inout ParserState) throws -> LiteralExpr {
        let token = try state.take()
        
        let kind: LiteralExpr.Kind = switch token.kind {
        case .double(let value): .numeric(value, isInt: false)
        case .int(let value): .numeric(Double(value), isInt: true)
        case .hex(let value): .numeric(Double(value), isInt: true)
        case .string(let value): .string(value)
        case .true: .true
        case .false: .false
        case .currentDate: .currentDate
        case .currentTime: .currentTime
        case .currentTimestamp: .currentTimestamp
        default: throw ParsingError(description: "Invalid Literal '\(token)'", sourceRange: token.range)
        }
        
        return LiteralExpr(kind: kind, range: token.range)
    }
    
    static func order(state: inout ParserState) throws -> Order {
        if try state.take(if: .asc) {
            return .asc
        } else if try state.take(if: .desc) {
            return .desc
        } else {
            return .asc
        }
    }
}

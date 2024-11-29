//
//  Parsers.swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//

enum Parsers {
    static func parse<Output>(
        source: String,
        parser: (inout ParserState) throws -> Output
    ) throws -> Output {
        var state = try ParserState(Lexer(source: source))
        return try parser(&state)
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
                try ExprParser()
                    .parse(state: &state)
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
        let first = try identifier(state: &state)
        if try state.take(if: .dot) {
            return TableName(schema: first, name: try identifier(state: &state))
        } else {
            return TableName(schema: nil, name: first)
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
        let cte: CommonTableExpression?
        let cteRecursive: Bool
        if try state.take(if: .with) {
            cteRecursive = try state.take(if: .recursive)
            cte = try Parsers.cte(state: &state)
        } else {
            cteRecursive = false
            cte = nil
        }
        
        let selects: [SelectCore]? = state.current.kind == .select || state.current.kind == .values
            ? try Parsers.commaDelimited(state: &state, element: Parsers.selectCore)
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
        return try Parsers.commaDelimited(state: &state, element: Parsers.orderingTerm)
    }
    
    static func limit(state: inout ParserState) throws -> SelectStmt.Limit? {
        guard try state.take(if: .limit) else { return nil }
        let expr = ExprParser()
        
        let first = try expr.parse(state: &state)
        
        switch state.current.kind {
        case .comma:
            try state.skip()
            let second = try expr.parse(state: &state)
            return SelectStmt.Limit(expr: second, offset: first)
        case .offset:
            try state.skip()
            let offset = try expr.parse(state: &state)
            return SelectStmt.Limit(expr: first, offset: offset)
        default:
            return SelectStmt.Limit(expr: first, offset: nil)
        }
    }
    
    static func orderingTerm(state: inout ParserState) throws -> OrderingTerm {
        let expr = try ExprParser()
            .parse(state: &state)
        
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
                try ExprParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
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
        
        let columns = try Parsers.commaDelimited(state: &state, element: Parsers.resultColumn)
        
        let from = try Parsers.from(state: &state)
        
        let `where` = try ExprParser()
            .take(if: .where, consume: true)
            .parse(state: &state)
        
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
        
        let exprs = try ExprParser()
            .commaSeparated()
            .parse(state: &state)
        
        let having = try ExprParser()
            .take(if: .having, consume: true)
            .parse(state: &state)
        
        return SelectCore.GroupBy(expressions: exprs, having: having)
    }
    
    static func window(state: inout ParserState) throws -> SelectCore.Window {
        let name = try IdentifierParser().parse(state: &state)
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
        let tableOrSubquery = try Parsers.tableOrSubquery(state: &state)
        
        if state.current.kind == .comma {
            try state.skip()
            
            let more = try Parsers.commaDelimited(state: &state, element: Parsers.tableOrSubquery)
            
            return .tableOrSubqueries([tableOrSubquery] + more)
        } else {
            // No comma, we are in join clause
            return .join(
                try Parsers.joinClause(state: &state, tableOrSubquery: tableOrSubquery)
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
            let expr = try ExprParser()
                .parse(state: &state)
            
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
            let (schema, table) = try TableAndSchemaNameParser()
                .parse(state: &state)
            
            if state.current.kind == .openParen {
                let args = try ExprParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
                
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
                let result = try Parsers.parens(state: &state, value: Parsers.joinClauseOrTableOrSubqueries)
                
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
        let op = try Parsers.joinOperator(state: &state)
        
        let tableOrSubquery = try Parsers.tableOrSubquery(state: &state)
        
        let constraint = try Parsers.joinConstraint(state: &state)
        
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
    
    static func commaDelimited<Element>(
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) throws -> [Element] {
        return try delimited(by: .comma, state: &state, element: element)
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

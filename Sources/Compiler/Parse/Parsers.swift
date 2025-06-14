//
//  swift
//
//
//  Created by Wes Wickwire on 11/12/24.
//

import OrderedCollections

enum Parsers {
    static func parse<Output>(
        source: String,
        parser: (inout ParserState) throws -> Output
    ) rethrows -> (Output, Diagnostics) {
        var state = ParserState(Lexer(source: source))
        let stmts = try parser(&state)
        return (stmts, state.diagnostics)
    }
    
    static func parse(source: String) -> ([any StmtSyntax], Diagnostics) {
        var state = ParserState(Lexer(source: source))
        let stmts = stmts(state: &state)
        return (stmts, state.diagnostics)
    }
    
    static func stmts(state: inout ParserState) -> [any StmtSyntax] {
        return stmts(state: &state, end: .eof)
    }
    
    static func stmts(state: inout ParserState, end: Token.Kind) -> [any StmtSyntax] {
        var stmts: [any StmtSyntax] = []
        
        repeat {
            do {
                try stmts.append(stmt(state: &state))
                state.resetParameterIndex()
            } catch {
                recover(state: &state)
            }
        } while state.take(if: .semiColon) && state.current.kind != end
        
        return stmts
    }
    
    static func stmt(state: inout ParserState) throws -> any StmtSyntax {
        switch (state.current.kind, state.peek.kind) {
        case (.create, .table):
            return try createTableStmt(state: &state)
        case (.create, .virtual):
            return try createVirutalTable(state: &state)
        case (.create, .index):
            return try createIndex(state: &state)
        case (.create, .unique) where state.peek2.kind == .index:
            return try createIndex(state: &state)
        case (.alter, .table):
            return try alterStmt(state: &state)
        case (.create, .view),
            (.create, .temp) where state.peek2.kind == .view,
            (.create, .temporary) where state.peek2.kind == .view:
            return try createView(state: &state)
        case (.create, .trigger):
            return try createTrigger(state: &state)
        case (.drop, .trigger):
            return dropTrigger(state: &state)
        case (.select, _):
            return try selectStmt(state: &state)
        case (.insert, _):
            return try insertStmt(state: &state)
        case (.update, _):
            return try updateStmt(state: &state)
        case (.delete, _):
            return try deleteStmt(state: &state)
        case (.define, _):
            return try definition(state: &state)
        case (.pragma, _):
            return try pragma(state: &state)
        case (.drop, .table):
            return dropTable(state: &state)
        case (.drop, .index):
            return dropIndex(state: &state)
        case (.drop, .view):
            return dropView(state: &state)
        case (.reindex, _):
            return reindex(state: &state)
        case (.with, _):
            let start = state.current
            let with = try take(if: .with, state: &state, parse: with)
            
            switch state.current.kind {
            case .select:
                return try selectStmt(state: &state, start: start, with: with)
            case .insert:
                return try insertStmt(state: &state, start: start, with: with)
            case .delete:
                return try deleteStmt(state: &state, start: start, with: with)
            default:
                state.diagnostics.add(.unexpectedToken(of: state.current.kind, at: state.location))
                return EmptyStmtSyntax(id: state.nextId(), location: state.current.location)
            }
        case (.semiColon, _), (.eof, _):
            state.skip()
            return EmptyStmtSyntax(id: state.nextId(), location: state.current.location)
        default:
            state.diagnostics.add(.unexpectedToken(of: state.current.kind, at: state.location))
            return EmptyStmtSyntax(id: state.nextId(), location: state.current.location)
        }
    }
    
    static func insertStmt(state: inout ParserState) throws -> InsertStmtSyntax {
        let start = state.current
        let with = try take(if: .with, state: &state, parse: with)
        return try insertStmt(
            state: &state,
            start: start,
            with: with
        )
    }
    
    /// https://www.sqlite.org/lang_insert.html
    static func insertStmt(
        state: inout ParserState,
        start: Token,
        with: WithSyntax?
    ) throws -> InsertStmtSyntax {
        let action = insertAction(state: &state)
        state.consume(.into)
        let tableName = tableName(state: &state)
        let alias = maybeAlias(state: &state)
        let columns = take(if: .openParen, state: &state, parse: columnNameList)
        let values = try insertValues(state: &state)
        let returningClause = try take(if: .returning, state: &state, parse: returningClause)
        
        return InsertStmtSyntax(
            id: state.nextId(),
            with: with,
            action: action,
            tableName: tableName,
            tableAlias: alias,
            columns: columns,
            values: values,
            returningClause: returningClause,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/lang_insert.html
    static func insertValues(
        state: inout ParserState
    ) throws -> InsertStmtSyntax.Values? {
        if state.take(if: .default) {
            state.consume(.values)
            return nil
        } else {
            let select = try selectStmt(state: &state)
            let upsertClause = try state.current.kind == .on ? upsertClause(state: &state) : nil
            return .init(id: state.nextId(), select: select, upsertClause: upsertClause)
        }
    }
    
    /// Example: INSERT
    /// Example: REPLACE
    /// https://www.sqlite.org/lang_insert.html
    static func insertAction(
        state: inout ParserState
    ) -> InsertStmtSyntax.Action {
        let token = state.take()
        
        let kind: InsertStmtSyntax.Action.Kind
        switch token.kind {
        case .replace: kind = .replace
        case .insert: kind = .insert(take(if: .or, state: &state, parse: or))
        default:
            state.diagnostics.add(.unexpectedToken(of: token.kind, at: token.location))
            kind = .insert(nil)
        }
        
        return InsertStmtSyntax.Action(id: state.nextId(), kind: kind, location: token.location)
    }
    
    /// Example: OR ABORT
    /// https://www.sqlite.org/lang_insert.html
    static func or(state: inout ParserState) -> OrSyntax {
        state.consume(.or)
        let token = state.take()
        let kind: OrSyntax.Kind
        switch token.kind {
        case .abort: kind = .abort
        case .fail: kind = .fail
        case .ignore: kind = .ignore
        case .replace: kind = .replace
        case .rollback: kind = .rollback
        default:
            state.diagnostics.add(.unexpectedToken(of: token.kind, at: token.location))
            kind = .ignore
        }
        return OrSyntax(id: state.nextId(),kind: kind, location: token.location)
    }
    
    /// https://www.sqlite.org/pragma.html
    static func pragma(state: inout ParserState) throws -> PragmaStmtSyntax {
        let start = state.take(.pragma)
        
        let schema: IdentifierSyntax?
        if state.peek.kind == .dot {
            schema = identifier(state: &state)
            state.skip()
        } else {
            schema = nil
        }
        
        let name = identifier(state: &state)
        
        let isFunctionCall: Bool
        let value: ExprSyntax?
        switch state.current.kind {
        case .openParen:
            isFunctionCall = true
            // The parens could technically get parsed by the `expr` but
            // then the expr type would technically be different.
            value = try parens(state: &state) { state in
                try expr(state: &state)
            }
        case .equal:
            isFunctionCall = false
            state.skip()
            value = try expr(state: &state)
        default:
            state.diagnostics.add(.unexpectedToken(
                of: state.current.kind,
                expectedAnyOf: .equal, .openParen,
                at: state.current.location
            ))
            // Still try to parse the value
            value = try expr(state: &state)
            isFunctionCall = false
        }
        
        return PragmaStmtSyntax(
            id: state.nextId(),
            schema: schema,
            name: name,
            value: value,
            isFunctionCall: isFunctionCall,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/lang_createindex.html
    static func createIndex(state: inout ParserState) throws -> CreateIndexStmtSyntax {
        let create = state.take(.create)
        let unique = state.take(if: .unique)
        state.consume(.index)
        let ifNotExists = ifNotExists(state: &state)
        
        let schema: IdentifierSyntax?
        if state.peek.kind == .dot {
            schema = identifier(state: &state)
            state.consume(.dot)
        } else {
            schema = nil
        }
        
        let indexName = identifier(state: &state)
        state.consume(.on)
        let tableName = identifier(state: &state)
        let indexedColumns = try commaDelimitedInParens(state: &state, element: indexedColumn)
        let whereExpr = try state.take(if: .where) ? expr(state: &state) : nil
        
        return CreateIndexStmtSyntax(
            id: state.nextId(),
            unique: unique,
            ifNotExists: ifNotExists,
            schemaName: schema,
            name: indexName,
            table: tableName,
            indexedColumns: indexedColumns,
            whereExpr: whereExpr,
            location: state.location(from: create)
        )
    }
    
    /// https://www.sqlite.org/lang_dropindex.html
    static func dropIndex(state: inout ParserState) -> DropIndexStmtSyntax {
        let drop = state.take(.drop)
        state.consume(.index)
        let ifExists = ifExists(state: &state)
        
        let schema: IdentifierSyntax?
        if state.peek.kind == .dot {
            schema = identifier(state: &state)
            state.consume(.dot)
        } else {
            schema = nil
        }
        
        let indexName = identifier(state: &state)
        
        return DropIndexStmtSyntax(
            id: state.nextId(),
            ifExists: ifExists,
            schemaName: schema,
            name: indexName,
            location: state.location(from: drop)
        )
    }
    
    /// https://www.sqlite.org/lang_reindex.html
    static func reindex(state: inout ParserState) -> ReindexStmtSyntax {
        let reindex = state.take(.reindex)
        
        let schema: IdentifierSyntax?
        if state.peek.kind == .dot {
            schema = identifier(state: &state)
            state.consume(.dot)
        } else {
            schema = nil
        }
        
        let name = state.current.kind.isSymbol ? identifier(state: &state) : nil
        return ReindexStmtSyntax(
            id: state.nextId(),
            schemaName: schema,
            name: name,
            location: state.location(from: reindex)
        )
    }
    
    /// https://www.sqlite.org/lang_createview.html
    static func createView(state: inout ParserState) throws -> CreateViewStmtSyntax {
        let create = state.take(.create)
        let temp = state.take(if: .temp) || state.take(if: .temporary)
        state.consume(.view)
        let ifNotExists = ifNotExists(state: &state)
        
        let schema: IdentifierSyntax?
        if state.peek.kind == .dot {
            schema = identifier(state: &state)
            state.consume(.dot)
        } else {
            schema = nil
        }
        let name = identifier(state: &state)
        
        let columns = state.current.kind == .openParen
            ? commaDelimitedInParens(state: &state, element: identifier)
            : []
        state.consume(.as)
        let select = try selectStmt(state: &state)
        return CreateViewStmtSyntax(
            id: state.nextId(),
            temp: temp,
            ifNotExists: ifNotExists,
            schemaName: schema,
            name: name,
            columnNames: columns,
            select: select,
            location: state.location(from: create)
        )
    }
    
    /// https://www.sqlite.org/lang_dropview.html
    static func dropView(state: inout ParserState) -> DropViewStmtSyntax {
        let drop = state.take(.drop)
        state.consume(.view)
        let ifExists = ifExists(state: &state)
        let (schema, view) = tableAndSchemaName(state: &state)
        return DropViewStmtSyntax(
            id: state.nextId(),
            location: state.location(from: drop),
            ifExists: ifExists,
            schemaName: schema,
            viewName: view
        )
    }
    
    /// Will optionally parse `IF NOT EXISTS` if the first token is `IF`
    static func ifNotExists(state: inout ParserState) -> Bool {
        guard state.take(if: .if) else { return false }
        state.consume(.not)
        state.consume(.exists)
        return true
    }
    
    /// Will optionally parse `IF EXISTS` if the first token is `IF`
    static func ifExists(state: inout ParserState) -> Bool {
        guard state.take(if: .if) else { return false }
        state.consume(.exists)
        return true
    }
    
    /// https://www.sqlite.org/syntax/upsert-clause.html
    static func upsertClause(
        state: inout ParserState
    ) throws -> UpsertClauseSyntax {
        let on = state.take(.on)
        state.consume(.conflict)
        
        let conflictTarget = try conflictTarget(state: &state)
        
        state.consume(.do)
        
        if state.take(if: .nothing) {
            return .init(
                id: state.nextId(),
                confictTarget: conflictTarget,
                doAction: .nothing,
                location: on.location.spanning(state.current.location)
            )
        }
        
        state.consume(.update)
        state.consume(.set)
        
        let sets = try delimited(by: .comma, state: &state, element: setAction)
        
        let whereExpr: (any ExprSyntax)? = if state.take(if: .where) {
            try expr(state: &state)
        } else {
            nil
        }
        
        return UpsertClauseSyntax(
            id: state.nextId(),
            confictTarget: conflictTarget,
            doAction: .updateSet(sets: sets, where: whereExpr),
            location: on.location.spanning(state.current.location)
        )
    }
    
    /// https://www.sqlite.org/lang_insert.html
    static func setAction(
        state: inout ParserState
    ) throws -> SetActionSyntax {
        let column: SetActionSyntax.Column
        if state.current.kind == .openParen {
            let columns = parens(state: &state) { state in
                delimited(by: .comma, state: &state, element: identifier)
            }
            
            column = .list(columns)
        } else {
            column = .single(identifier(state: &state))
        }
        
        state.consume(.equal)
        
        let expr = try expr(state: &state)
        
        return SetActionSyntax(id: state.nextId(), column: column, expr: expr)
    }
    
    /// https://www.sqlite.org/syntax/upsert-clause.html
    static func conflictTarget(
        state: inout ParserState
    ) throws -> UpsertClauseSyntax.ConflictTarget? {
        guard state.current.kind == .openParen else { return nil }
        
        let columns = try parens(state: &state) { state in
            try delimited(by: .comma, state: &state, element: indexedColumn)
        }
        
        let condition: (any ExprSyntax)? = if state.take(if: .where) {
            try expr(state: &state)
        } else {
            nil
        }
        
        return UpsertClauseSyntax.ConflictTarget(columns: columns, condition: condition)
    }
    
    /// https://www.sqlite.org/syntax/returning-clause.html
    static func returningClause(state: inout ParserState) throws -> ReturningClauseSyntax {
        let start = state.take(.returning)
        
        let values: [ReturningClauseSyntax.Value] = try delimited(
            by: .comma,
            state: &state
        ) { state in
            if state.take(if: .star) {
                return .all
            } else {
                let expr = try expr(state: &state)
                let alias = maybeAlias(state: &state)
                return .expr(expr: expr, alias: alias)
            }
        }
        
        return ReturningClauseSyntax(id: state.nextId(), values: values, location: state.location(from: start))
    }
    
    /// https://www.sqlite.org/lang_update.html
    static func updateStmt(state: inout ParserState) throws -> UpdateStmtSyntax {
        let start = state.location
        let with = try take(if: .with, state: &state, parse: with)
        state.consume(.update)
        let or = take(if: .or, state: &state, parse: or)
        let tableName = qualifiedTableName(state: &state)
        state.consume(.set)
        let sets = try delimited(by: .comma, state: &state, element: setAction)
        let from = try from(state: &state)
        let whereExpr = try take(if: .where, state: &state) { state in
            state.consume(.where)
            return try expr(state: &state)
        }
        let returningClause = try take(if: .returning, state: &state, parse: returningClause)
        return UpdateStmtSyntax(
            id: state.nextId(),
            with: with,
            or: or,
            tableName: tableName,
            sets: sets,
            from: from,
            whereExpr: whereExpr,
            returningClause: returningClause,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/lang_delete.html
    static func deleteStmt(state: inout ParserState) throws -> DeleteStmtSyntax {
        let start = state.current
        let with = try take(if: .with, state: &state, parse: with)
        return try deleteStmt(
            state: &state,
            start: start,
            with: with
        )
    }
    
    /// https://www.sqlite.org/lang_delete.html
    static func deleteStmt(
        state: inout ParserState,
        start: Token,
        with: WithSyntax?
    ) throws -> DeleteStmtSyntax {
        state.consume(.delete)
        state.consume(.from)
        let table = qualifiedTableName(state: &state)
        let whereExpr = try state.take(if: .where) ? expr(state: &state) : nil
        let returningClause = try state.current.kind == .returning ? returningClause(state: &state) : nil
        return DeleteStmtSyntax(
            id: state.nextId(),
            with: with,
            table: table,
            whereExpr: whereExpr,
            returningClause: returningClause,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/syntax/qualified-table-name.html
    static func qualifiedTableName(
        state: inout ParserState
    ) -> QualifiedTableNameSyntax {
        let tableName = tableName(state: &state)
        let alias = maybeAlias(state: &state)
        
        let indexed: QualifiedTableNameSyntax.Indexed?
        if state.take(if: .indexed) {
            state.consume(.by)
            indexed = .by(identifier(state: &state))
        } else if state.take(if: .not) {
            state.consume(.indexed)
            indexed = .not
        } else {
            indexed = nil
        }
        
        return QualifiedTableNameSyntax(
            id: state.nextId(),
            tableName: tableName,
            alias: alias,
            indexed: indexed,
            location: state.location(from: tableName.location)
        )
    }
    
    /// https://www.sqlite.org/syntax/indexed-column.html
    static func indexedColumn(
        state: inout ParserState
    ) throws -> IndexedColumnSyntax {
        let expr = try expr(state: &state)
        
        let collation: IdentifierSyntax? = if state.take(if: .collate) {
            identifier(state: &state)
        } else {
            nil
        }
        
        let order = order(state: &state)
        return IndexedColumnSyntax(
            id: state.nextId(),
            expr: expr,
            collation: collation,
            order: order
        )
    }
    
    /// https://www.sqlite.org/lang_with.html
    static func with(state: inout ParserState) throws -> WithSyntax {
        let with = state.take(.with)
        let recursive = state.take(if: .recursive)
        let ctes = try commaDelimited(state: &state, element: cte)
        
        return WithSyntax(
            id: state.nextId(),
            location: state.location(from: with),
            recursive: recursive,
            ctes: ctes
        )
    }
    
    /// https://www.sqlite.org/syntax/common-table-expression.html
    static func cte(
        state: inout ParserState
    ) throws -> CommonTableExpressionSyntax {
        let start = state.current
        let table = identifier(state: &state)
        
        let columns = take(if: .openParen, state: &state) { state in
            parens(state: &state) { state in
                delimited(by: .comma, state: &state, element: identifier)
            }
        }

        state.consume(.as)
        
        let materialized: Bool
        if state.take(if: .not) {
            state.consume(.materialized)
            materialized = false
        } else if state.take(if: .materialized) {
            materialized = true
        } else {
            materialized = false
        }
        
        let select = try parens(state: &state, value: selectStmt)
        
        return CommonTableExpressionSyntax(
            id: state.nextId(),
            table: table,
            columns: columns ?? [],
            materialized: materialized,
            select: select,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/syntax/join-constraint.html
    static func joinConstraint(state: inout ParserState) throws -> JoinConstraintSyntax {
        let start = state.location
        
        let kind: JoinConstraintSyntax.Kind
        if state.take(if: .on) {
            kind = try .on(expr(state: &state))
        } else if state.take(if: .using) {
            kind = .using(
                parens(state: &state) { state in
                    commaDelimited(state: &state, element: identifier)
                }
            )
        } else {
            kind = .none
        }
        
        return JoinConstraintSyntax(
            id: state.nextId(),
            kind: kind,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/syntax/join-operator.html
    static func joinOperator(state: inout ParserState) -> JoinOperatorSyntax {
        let token = state.take()
        
        let kind: JoinOperatorSyntax.Kind
        switch token.kind {
        case .comma: kind = .comma
        case .join: kind = .join
        case .natural:
            let token = state.take()
            switch token.kind {
            case .join: kind = .natural
            case .left:
                if state.take(if: .outer) {
                    state.consume(.join)
                    kind = .left(natural: true, outer: true)
                } else {
                    state.consume(.join)
                    kind = .left(natural: true)
                }
            case .right:
                state.consume(.join)
                kind = .right(natural: true)
            case .inner:
                state.consume(.join)
                kind = .inner(natural: true)
            case .full:
                state.consume(.join)
                kind = .full(natural: true)
            default:
                state.diagnostics.add(.unexpectedToken(of: token.kind, at: token.location))
                kind = .full(natural: true, outer: false)
            }
        case .left:
            if state.take(if: .outer) {
                state.consume(.join)
                kind = .left(outer: true)
            } else {
                state.consume(.join)
                kind = .left(outer: false)
            }
        case .right:
            state.consume(.join)
            kind = .right()
        case .inner:
            state.consume(.join)
            kind = .inner()
        case .cross:
            state.consume(.join)
            kind = .cross
        case .full:
            state.consume(.join)
            kind = .full()
        default:
            state.diagnostics.add(.init("Invalid join operator", at: state.current.location))
            kind = .full()
        }
        
        return JoinOperatorSyntax(
            id: state.nextId(),
            kind: kind,
            location: state.location(from: token)
        )
    }
    
    static func from(state: inout ParserState) throws -> FromSyntax? {
        let output = try take(if: .from, state: &state) { state in
            state.consume(.from)
            return try joinClauseOrTableOrSubqueries(state: &state)
        }
        
        return switch output {
        case let .join(joinClause): .join(joinClause)
        case let .tableOrSubqueries(tableOrSubqueries): .tableOrSubqueries(tableOrSubqueries)
        case nil: nil
        }
    }
    
    /// https://www.sqlite.org/syntax/column-name-list.html
    static func columnNameList(state: inout ParserState) -> [IdentifierSyntax] {
        return parens(state: &state) { state in
            delimited(by: .comma, state: &state, element: identifier)
        }
    }
    
    static func tableName(state: inout ParserState) -> TableNameSyntax {
        let names = tableAndSchemaName(state: &state)
        return TableNameSyntax(id: state.nextId(), schema: names.schema, name: names.table)
    }
    
    static func tableAndSchemaName(state: inout ParserState) -> (schema: IdentifierSyntax?, table: IdentifierSyntax) {
        let first = identifier(state: &state)
        if state.take(if: .dot) {
            return (first, identifier(state: &state))
        } else {
            return (nil, first)
        }
    }
    
    /// https://www.sqlite.org/syntax/select-stmt.html
    static func selectStmt(state: inout ParserState) throws -> SelectStmtSyntax {
        let start = state.current
        let with = try take(if: .with, state: &state, parse: with)
        return try selectStmt(state: &state, start: start, with: with)
    }
    
    /// https://www.sqlite.org/syntax/select-stmt.html
    static func selectStmt(
        state: inout ParserState,
        start: Token,
        with: WithSyntax?
    ) throws -> SelectStmtSyntax {
        let selects = try selects(state: &state)
        let orderBy = try orderingTerms(state: &state)
        let limit = try limit(state: &state)
        
        return SelectStmtSyntax(
            id: state.nextId(),
            with: with,
            selects: .init(selects),
            orderBy: orderBy,
            limit: limit,
            location: state.location(from: start)
        )
    }
    
    static func selects(state: inout ParserState) throws -> SelectStmtSyntax.Selects {
        let core = try selectCore(state: &state)
        
        return if let op = compoundOperator(state: &state) {
            try .compound(core, op, selects(state: &state))
        } else {
            .single(core)
        }
    }
    
    static func compoundOperator(state: inout ParserState) -> CompoundOperatorSyntax? {
        let start = state.location
        let kind: CompoundOperatorSyntax.Kind
        switch (state.current.kind, state.peek.kind) {
        case (.union, .all): kind = .unionAll
        case (.union, _): kind = .union
        case (.intersect, _): kind = .intersect
        case (.except, _): kind = .except
        default: return nil
        }
        
        state.skip()
        if kind == .unionAll {
            state.skip()
        }
        
        return CompoundOperatorSyntax(
            id: state.nextId(),
            kind: kind,
            location: state.location(
                from: start
            )
        )
    }
    
    static func orderingTerms(state: inout ParserState) throws -> [OrderingTermSyntax] {
        guard state.take(if: .order) else { return [] }
        state.consume(.by)
        return try commaDelimited(state: &state, element: orderingTerm)
    }
    
    static func limit(state: inout ParserState) throws -> SelectStmtSyntax.Limit? {
        guard state.take(if: .limit) else { return nil }
        let first = try expr(state: &state)
        
        switch state.current.kind {
        case .comma:
            state.skip()
            let second = try expr(state: &state)
            return SelectStmtSyntax.Limit(expr: second, offset: first)
        case .offset:
            state.skip()
            let offset = try expr(state: &state)
            return SelectStmtSyntax.Limit(expr: first, offset: offset)
        default:
            return SelectStmtSyntax.Limit(expr: first, offset: nil)
        }
    }
    
    /// https://www.sqlite.org/syntax/ordering-term.html
    static func orderingTerm(state: inout ParserState) throws -> OrderingTermSyntax {
        let expr = try expr(state: &state)
        
        let order = order(state: &state)
        
        let nulls: OrderingTermSyntax.Nulls?
        if state.take(if: .nulls) {
            if state.take(if: .first) {
                nulls = .first
            } else if state.take(if: .last) {
                nulls = .last
            } else {
                state.diagnostics.add(.unexpectedToken(
                    of: state.current.kind,
                    expectedAnyOf: .first, .last,
                    at: state.location
                ))
                nulls = .first
            }
        } else {
            nulls = nil
        }
        
        return OrderingTermSyntax(
            id: state.nextId(),
            expr: expr,
            order: order,
            nulls: nulls,
            location: state.location(from: expr.location)
        )
    }
    
    /// https://www.sqlite.org/syntax/select-stmt.html
    static func selectCore(state: inout ParserState) throws -> SelectCoreSyntax {
        // Check if its values and to just get it out of the way
        if state.take(if: .values) {
            return .values(
                try commaDelimited(state: &state) { state in
                    try commaDelimitedInParens(state: &state) { try expr(state: &$0) }
                }
            )
        }
        
        state.consume(.select)
        
        let distinct = if state.take(if: .distinct) {
            true
        } else if state.take(if: .all) {
            false
        } else {
            false
        }
        
        let columns = try commaDelimited(state: &state, element: resultColumn)
        
        let from = try from(state: &state)
        
        let `where` = try take(if: .where, state: &state) { state in
            state.consume(.where)
            return try expr(state: &state)
        }
        
        let groupBy = try groupBy(state: &state)
        
        let windows = take(if: .window, state: &state) { state in
            state.consume(.window)
            return commaDelimited(state: &state, element: window)
        }
        
        let select = SelectCoreSyntax.Select(
            distinct: distinct,
            columns: columns,
            from: from,
            where: `where`,
            groupBy: groupBy,
            windows: windows ?? []
        )
        
        return .select(select)
    }
    
    /// https://www.sqlite.org/syntax/select-stmt.html
    static func groupBy(state: inout ParserState) throws -> SelectCoreSyntax.GroupBy? {
        guard state.take(if: .group) else { return nil }
        state.consume(.by)
        
        let exprs = try commaDelimited(state: &state) { try expr(state: &$0) }
        
        let having = try take(if: .having, state: &state) { state in
            state.consume(.having)
            return try expr(state: &state)
        }
        
        return SelectCoreSyntax.GroupBy(expressions: exprs, having: having)
    }
    
    static func window(state: inout ParserState) -> SelectCoreSyntax.Window {
        let name = identifier(state: &state)
        state.consume(.as)
        let window = windowDef(state: &state)
        return SelectCoreSyntax.Window(name: name, window: window)
    }
    
    static func windowDef(state: inout ParserState) -> WindowDefinitionSyntax {
        fatalError("Not yet implemented")
    }
    
    enum JoinClauseOrTableOrSubqueries {
        case join(JoinClauseSyntax)
        case tableOrSubqueries([TableOrSubquerySyntax])
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
            state.skip()
            
            let more = try commaDelimited(state: &state, element: Self.tableOrSubquery)
            
            return .tableOrSubqueries([tableOrSubquery] + more)
        } else {
            // No comma, we are in join clause
            return try .join(
                joinClause(state: &state, tableOrSubquery: tableOrSubquery)
            )
        }
    }
    
    /// https://www.sqlite.org/syntax/result-column.html
    static func resultColumn(state: inout ParserState) throws -> ResultColumnSyntax {
        let start = state.current.location
        switch state.current.kind {
        case .star:
            state.skip()
            return ResultColumnSyntax(
                id: state.nextId(),
                kind: .all(table: nil),
                location: state.location(from: start)
            )
        case let .identifier(table) where state.peek.kind == .dot && state.peek2.kind == .star:
            let table = IdentifierSyntax(value: table, location: state.current.location)
            state.skip()
            state.consume(.dot)
            state.consume(.star)
            return ResultColumnSyntax(
                id: state.nextId(),
                kind: .all(table: table),
                location: state.location(from: start)
            )
        default:
            let expr = try expr(state: &state)
            let alias = maybeAlias(state: &state, asRequired: false)
            return ResultColumnSyntax(
                id: state.nextId(),
                kind: .expr(expr, as: alias),
                location: state.location(from: start)
            )
        }
    }
    
    /// https://www.sqlite.org/syntax/table-or-subquery.html
    static func tableOrSubquery(state: inout ParserState) throws -> TableOrSubquerySyntax {
        let start = state.location
        let kind: TableOrSubquerySyntax.Kind
        
        switch state.current.kind {
        case .identifier:
            let (schema, table) = tableAndSchemaName(state: &state)
            
            if state.current.kind == .openParen {
                let args = try commaDelimitedInParens(state: &state) { try expr(state: &$0) }
                let alias = maybeAlias(state: &state, asRequired: false)
                kind = .tableFunction(schema: schema, table: table, args: args, alias: alias)
            } else {
                let alias = maybeAlias(state: &state, asRequired: false)
                
                let indexedBy: IdentifierSyntax?
                switch state.current.kind {
                case .indexed:
                    state.skip()
                    state.consume(.by)
                    indexedBy = identifier(state: &state)
                case .not:
                    state.skip()
                    state.consume(.indexed)
                    indexedBy = nil
                default:
                    indexedBy = nil
                }
                
                let table = TableOrSubquerySyntax.Table(
                    schema: schema,
                    name: table,
                    alias: alias,
                    indexedBy: indexedBy
                )
                
                kind = .table(table)
            }
        case .openParen:
            if state.peek.kind == .select {
                let subquery = try parens(state: &state, value: selectStmt)
                let alias = maybeAlias(state: &state, asRequired: false)
                kind = .subquery(subquery, alias: alias)
            } else {
                let result = try parens(state: &state, value: joinClauseOrTableOrSubqueries)
                
                switch result {
                case let .join(joinClause):
                    kind = .join(joinClause)
                case let .tableOrSubqueries(table):
                    // Note: Using SQLite directly it seems to allow an alias, but its not usable.
                    //
                    // Example:
                    // `SELECT * FROM (foo, bar) AS baz` is valid
                    // However doing then `SELECT baz.*` is not valid.
                    //
                    // I could be misinterpreting the diagram and the alias is coming from
                    // somewhere else but it is not clear to me at the moment.
                    kind = .tableOrSubqueries(table)
                }
            }
        default:
            throw state.diagnostics.add(.init("Expected table or subquery", at: state.current.location))
        }
        
        return TableOrSubquerySyntax(
            id: state.nextId(),
            kind: kind,
            location: state.location(from: start)
        )
    }
    
    static func joinClause(
        state: inout ParserState,
        tableOrSubquery: TableOrSubquerySyntax
    ) throws -> JoinClauseSyntax {
        let joinOperatorStarts: Set<Token.Kind> = [.natural, .comma, .left, .right, .full, .inner, .cross, .join]
        let start = state.location
        
        var joins: [JoinClauseSyntax.Join] = []
        while joinOperatorStarts.contains(state.current.kind) {
            try joins.append(join(state: &state))
        }
        return JoinClauseSyntax(
            id: state.nextId(),
            tableOrSubquery: tableOrSubquery,
            joins: joins,
            location: state.location(from: start)
        )
    }
    
    static func join(state: inout ParserState) throws -> JoinClauseSyntax.Join {
        let op = joinOperator(state: &state)
        
        let tableOrSubquery = try tableOrSubquery(state: &state)
        
        let constraint = try joinConstraint(state: &state)
        
        return JoinClauseSyntax.Join(
            op: op,
            tableOrSubquery: tableOrSubquery,
            constraint: constraint
        )
    }
    
    /// Will to parse out an alias
    /// e.g. `AS foo`.
    static func maybeAlias(
        state: inout ParserState,
        asRequired: Bool = true
    ) -> AliasSyntax? {
        switch state.current.kind {
        case .as:
            let start = state.take()
            let ident = identifier(state: &state)
            return AliasSyntax(
                id: state.nextId(),
                identifier: ident,
                location: state.location(from: start)
            )
        case .identifier where !asRequired:
            let ident = identifier(state: &state)
            return AliasSyntax(
                id: state.nextId(),
                identifier: ident,
                location: ident.location
            )
        default:
            return nil
        }
    }
    
    /// https://www.sqlite.org/syntax/table-options.html
    static func tableOptions(state: inout ParserState) -> TableOptionsSyntax {
        let start = state.location
        var options: TableOptionsSyntax.Kind = []
        
        repeat {
            switch state.current.kind {
            case .without:
                state.skip()
                state.consume(.rowid)
                options = options.union(.withoutRowId)
            case .strict:
                state.skip()
                options = options.union(.strict)
            case .eof, .semiColon:
                break
            default:
                state.diagnostics.add(.unexpectedToken(
                    of: state.current.kind,
                    expectedAnyOf: .without, .strict,
                    at: state.current.location
                ))
                break
            }
        } while state.take(if: .comma)
        
        return TableOptionsSyntax(id: state.nextId(), kind: options, location: state.location(from: start))
    }
    
    /// https://www.sqlite.org/syntax/type-name.html
    static func typeName(
        state: inout ParserState,
        doNotConsumeWords: Set<Substring>? = nil
    ) -> TypeNameSyntax {
        var name = identifier(state: &state)
        
        while case let .identifier(s) = state.current.kind {
            if let doNotConsumeWords, doNotConsumeWords.contains(s) {
                break
            }
            
            let upperBound = state.current.location.upperBound
            state.skip()
            name.append(" \(s)", upperBound: upperBound)
        }
        
        if state.take(if: .openParen) {
            let first = signedNumber(state: &state)
            
            if state.take(if: .comma) {
                let second = signedNumber(state: &state)
                state.consume(.closeParen)
                let alias = maybeAlias(state: &state)
                return TypeNameSyntax(
                    id: state.nextId(),
                    name: name,
                    arg1: first,
                    arg2: second,
                    alias: alias,
                    location: state.location(from: name.location)
                )
            } else {
                state.consume(.closeParen)
                let alias = maybeAlias(state: &state)
                return TypeNameSyntax(
                    id: state.nextId(),
                    name: name,
                    arg1: first,
                    arg2: nil,
                    alias: alias,
                    location: state.location(from: name.location)
                )
            }
        } else {
            let alias = maybeAlias(state: &state)
            return TypeNameSyntax(
                id: state.nextId(),
                name: name,
                arg1: nil,
                arg2: nil,
                alias: alias,
                location: state.location(from: name.location)
            )
        }
    }
    
    /// https://www.sqlite.org/lang_altertable.html
    static func alterStmt(state: inout ParserState) throws -> AlterTableStmtSyntax {
        let alter = state.take(.alter)
        state.consume(.table)
        let names = tableAndSchemaName(state: &state)
        let kind = try alterKind(state: &state)
        return AlterTableStmtSyntax(
            id: state.nextId(),
            name: names.table,
            schemaName: names.schema,
            kind: kind,
            location: alter.location.spanning(state.current.location)
        )
    }
    
    /// https://www.sqlite.org/lang_altertable.html
    static func alterKind(state: inout ParserState) throws -> AlterTableStmtSyntax.Kind {
        let token = state.take()
        
        switch token.kind {
        case .rename:
            switch state.current.kind {
            case .to:
                state.skip()
                let newName = identifier(state: &state)
                return .rename(newName)
            default:
                _ = state.take(if: .column)
                let oldName = identifier(state: &state)
                state.consume(.to)
                let newName = identifier(state: &state)
                return .renameColumn(oldName, newName)
            }
        case .add:
            _ = state.take(if: .column)
            let column = try columnDef(state: &state)
            return .addColumn(column)
        case .drop:
            _ = state.take(if: .column)
            let column = identifier(state: &state)
            return .dropColumn(column)
        default:
            throw state.diagnostics.add(.unexpectedToken(
                of: token.kind,
                expectedAnyOf: .rename, .add, .add, .drop,
                at: token.location
            ))
        }
    }
    
    /// https://www.sqlite.org/lang_createtable.html
    static func createTableStmt(state: inout ParserState) throws -> CreateTableStmtSyntax {
        let create = state.take(.create)
        let isTemporary = state.take(if: .temp, or: .temporary)
        state.consume(.table)
        
        let ifNotExists = ifNotExists(state: &state)
        let (schema, table) = tableAndSchemaName(state: &state)
        
        if state.take(if: .as) {
            let select = try selectStmt(state: &state)
            return CreateTableStmtSyntax(
                id: state.nextId(),
                name: table,
                schemaName: schema,
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .select(select),
                location: create.location.spanning(state.current.location)
            )
        } else {
            let (columns, constraints) = try parens(state: &state) { state in
                let columns = try createTableStmtColumns(state: &state)
                let constraints = try tableConstraints(state: &state)
                return (columns, constraints)
            }

            let options = tableOptions(state: &state)
            
            return CreateTableStmtSyntax(
                id: state.nextId(),
                name: table,
                schemaName: schema,
                isTemporary: isTemporary,
                onlyIfExists: ifNotExists,
                kind: .columns(columns, constraints: constraints, options: options),
                location: create.location.spanning(state.current.location)
            )
        }
    }
    
    /// https://www.sqlite.org/lang_createvtab.html
    static func createVirutalTable(state: inout ParserState) throws -> CreateVirtualTableStmtSyntax {
        let create = state.take(.create)
        state.consume(.virtual)
        state.consume(.table)
        let ifNotExists = ifNotExists(state: &state)
        let name = tableName(state: &state)
        state.consume(.using)
        
        let moduleName = identifier(state: &state)
        let module: CreateVirtualTableStmtSyntax.Module = switch moduleName.value.uppercased() {
        case "FTS5": .fts5
        default: .unknown
        }
        
        let arguments = try commaDelimitedInParens(state: &state) { state in
            try virtualTableArgument(module: module, state: &state)
        }
        
        return CreateVirtualTableStmtSyntax(
            id: state.nextId(),
            ifNotExists: ifNotExists,
            tableName: name,
            module: module,
            moduleName: moduleName,
            arguments: arguments,
            location: state.location(from: create)
        )
    }
    
    static func virtualTableArgument(
        module: CreateVirtualTableStmtSyntax.Module,
        state: inout ParserState
    ) throws -> CreateVirtualTableStmtSyntax.ModuleArgument {
        switch module {
        case .fts5:
            if state.peek.kind == .equal {
                let name = identifier(state: &state)
                let value = try expr(state: &state)
                return .fts5Option(name: name, value: value)
            } else {
                let name = identifier(state: &state)
                
                let type = state.current.kind.isSymbol && state.current.kind != .unindexed
                    ? typeName(state: &state, doNotConsumeWords: ["UNINDEXED"])
                    : nil
                
                // This isnt allowed in FTS5, however will will allow it
                // so we can better generate the column types
                let notNull: SourceLocation?
                if state.current.kind == .not {
                    let not = state.take(.not)
                    state.consume(.null)
                    notNull = state.location(from: not)
                } else {
                    notNull = nil
                }
                
                let unindexed = state.take(if: .unindexed)
                return .fts5Column(
                    name: name,
                    typeName: type,
                    notNull: notNull,
                    unindexed: unindexed
                )
            }
        case .unknown:
            repeat {
                // We don't know what we are parsing, just skip it.
                state.skip()
            } while state.current.kind != .closeParen
                && state.current.kind != .comma
                && state.current.kind != .eof
            return .unknown
        }
    }
    
    /// https://www.sqlite.org/lang_createtable.html
    static func createTableStmtColumns(
        state: inout ParserState
    ) throws -> CreateTableStmtSyntax.Columns {
        var columns: CreateTableStmtSyntax.Columns = [:]
        
        repeat {
            let column = try columnDef(state: &state)
            columns[column.name] = column
        } while state.take(if: .comma) && state.current.kind.isSymbol
        
        return columns
    }
    
    /// https://www.sqlite.org/syntax/table-constraint.html
    static func tableConstraints(state: inout ParserState) throws -> [TableConstraintSyntax] {
        // Make sure there were actually constraints after the columns
        guard state.current.kind != .closeParen else { return [] }
        
        var constraints: [TableConstraintSyntax] = []
        
        repeat {
            guard let constraint = try tableConstraint(state: &state) else { continue }
            constraints.append(constraint)
        } while state.take(if: .comma)
        
        return constraints
    }
    
    /// https://www.sqlite.org/syntax/table-constraint.html
    static func tableConstraint(state: inout ParserState) throws -> TableConstraintSyntax? {
        let start = state.current.location
        let name: IdentifierSyntax? = if state.take(if: .constraint) {
            identifier(state: &state)
        } else {
            nil
        }
        
        let kind: TableConstraintSyntax.Kind
        switch state.current.kind {
        case .primary:
            state.skip()
            state.consume(.key)
            let columns = try commaDelimitedInParens(state: &state, element: indexedColumn)
            let conflictClause = conflictClause(state: &state)
            kind = .primaryKey(columns, conflictClause)
        case .unique:
            state.skip()
            let columns = try commaDelimitedInParens(state: &state, element: indexedColumn)
            let conflictClause = conflictClause(state: &state)
            kind = .primaryKey(columns, conflictClause)
        case .check:
            state.skip()
            kind = try .check(parens(state: &state, value: { try expr(state: &$0) }))
        case .foreign:
            state.skip()
            state.consume(.key)
            let columns = columnNameList(state: &state)
            let foreignKeyClause = foreignKeyClause(state: &state)
            kind = .foreignKey(columns, foreignKeyClause)
        default:
            state.diagnostics.add(.unexpected(token: state.current))
            return nil
        }
        
        return TableConstraintSyntax(
            id: state.nextId(),
            name: name,
            kind: kind,
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/syntax/column-def.html
    static func columnDef(state: inout ParserState) throws -> ColumnDefSyntax {
        let name = identifier(state: &state)
        let type = typeName(state: &state)
        var constraints: [ColumnConstraintSyntax] = []
        
        while state.current.kind != .comma,
              state.current.kind != .closeParen,
              state.current.kind != .eof,
              state.current.kind != .semiColon
        {
            guard let c = try columnConstraint(state: &state) else { continue }
            constraints.append(c)
        }
        
        return ColumnDefSyntax(id: state.nextId(), name: name, type: type, constraints: constraints)
    }
    
    /// https://www.sqlite.org/syntax/column-constraint.html
    static func columnConstraint(
        state: inout ParserState,
        name: IdentifierSyntax? = nil
    ) throws -> ColumnConstraintSyntax? {
        let start = state.current.location
        switch state.current.kind {
        case .constraint:
            state.skip()
            let name = identifier(state: &state)
            return try columnConstraint(state: &state, name: name)
        case .primary:
            return parsePrimaryKey(state: &state, name: name)
        case .not:
            state.skip()
            state.consume(.null)
            let conflictClause = conflictClause(state: &state)
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .notNull(conflictClause),
                location: state.location(from: start)
            )
        case .unique:
            state.skip()
            let conflictClause = conflictClause(state: &state)
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .unique(conflictClause),
                location: state.location(from: start)
            )
        case .check:
            state.skip()
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .check(expr),
                location: state.location(from: start)
            )
        case .default:
            state.skip()
            if state.current.kind == .openParen {
                let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
                return ColumnConstraintSyntax(
                    id: state.nextId(),
                    name: name,
                    kind: .default(expr),
                    location: state.location(from: start)
                )
            } else {
                return try ColumnConstraintSyntax(
                    id: state.nextId(),
                    name: name,
                    kind: .default(expr(state: &state)),
                    location: state.location(from: start)
                )
            }
        case .collate:
            state.skip()
            let collation = identifier(state: &state)
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .collate(collation),
                location: state.location(from: start)
            )
        case .references:
            let fk = foreignKeyClause(state: &state)
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .foreignKey(fk),
                location: state.location(from: start)
            )
        case .generated:
            state.skip()
            state.consume(.always)
            state.consume(.as)
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            let generated = parseGeneratedKind(state: &state)
            
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .generated(expr, generated),
                location: state.location(from: start)
            )
        case .as:
            let expr = try parens(state: &state) { try Parsers.expr(state: &$0) }
            let generated = parseGeneratedKind(state: &state)
            return ColumnConstraintSyntax(
                id: state.nextId(),
                name: name,
                kind: .generated(expr, generated),
                location: state.location(from: start)
            )
        default:
            state.diagnostics.add(.unexpectedToken(of: state.current.kind, at: state.location))
            state.skip()
            return nil
        }
    }
    
    /// https://www.sqlite.org/syntax/column-constraint.html
    private static func parseGeneratedKind(
        state: inout ParserState
    ) -> ColumnConstraintSyntax.GeneratedKind? {
        return if state.take(if: .stored) {
            .stored
        } else if state.take(if: .virtual) {
            .virtual
        } else {
            nil
        }
    }
    
    /// https://www.sqlite.org/syntax/column-constraint.html
    private static func parsePrimaryKey(
        state: inout ParserState,
        name: IdentifierSyntax?
    ) -> ColumnConstraintSyntax {
        let start = state.take(.primary)
        state.consume(.key)
        let order = order(state: &state)
        let conflictClause = conflictClause(state: &state)
        let autoincrement = state.take(if: .autoincrement)
        
        return ColumnConstraintSyntax(
            id: state.nextId(),
            name: name,
            kind: .primaryKey(order: order, conflictClause, autoincrement: autoincrement),
            location: state.location(from: start)
        )
    }
    
    /// https://www.sqlite.org/syntax/conflict-clause.html
    static func conflictClause(state: inout ParserState) -> ConfictClauseSyntax {
        guard state.current.kind == .on else { return .none }
        
        state.consume(.on)
        state.consume(.conflict)
        
        let token = state.take()
        switch token.kind {
        case .rollback: return .rollback
        case .abort: return .abort
        case .fail: return .fail
        case .ignore: return .ignore
        case .replace: return .replace
        default:
            state.diagnostics.add(.unexpected(token: token))
            return .ignore
        }
    }
    
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    static func foreignKeyClause(state: inout ParserState) -> ForeignKeyClauseSyntax {
        let references = state.take(.references)
        
        let table = identifier(state: &state)
        
        let columns = take(if: .openParen, state: &state) { state in
            commaDelimitedInParens(state: &state, element: identifier)
        }
        
        let actions = foreignKeyClauseActions(state: &state)
        
        return ForeignKeyClauseSyntax(
            id: state.nextId(),
            foreignTable: table,
            foreignColumns: columns ?? [],
            actions: actions,
            location: state.location(from: references)
        )
    }
    
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private static func foreignKeyClauseActions(
        state: inout ParserState
    ) -> [ForeignKeyClauseSyntax.Action] {
        guard let action = foreignKeyClauseAction(state: &state) else { return [] }
        
        switch action {
        case .onDo, .match:
            return [action] + foreignKeyClauseActions(state: &state)
        case .deferrable, .notDeferrable:
            // These cannot have a secondary action
            return [action]
        }
    }
    
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private static func foreignKeyClauseAction(
        state: inout ParserState
    ) -> ForeignKeyClauseSyntax.Action? {
        switch state.current.kind {
        case .on:
            state.skip()
            let on: ForeignKeyClauseSyntax.On
            if state.take(if: .delete) {
                on = .delete
            } else if state.take(if: .update) {
                on = .update
            } else {
                state.diagnostics.add(.init("Expected 'UPDATE' or 'DELETE'", at: state.current.location))
                on = .update
            }
            
            return .onDo(on, foreignKeyClauseOnDeleteOrUpdateAction(state: &state))
        case .match:
            state.skip()
            let name = identifier(state: &state)
            return .match(name, foreignKeyClauseActions(state: &state))
        case .not:
            state.skip()
            state.consume(.deferrable)
            return .notDeferrable(foreignKeyClauseDeferrable(state: &state))
        case .deferrable:
            state.skip()
            return .deferrable(foreignKeyClauseDeferrable(state: &state))
        default:
            return nil
        }
    }
    
    /// Parses out the action to be performed on an `ON` clause
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private static func foreignKeyClauseOnDeleteOrUpdateAction(
        state: inout ParserState
    ) -> ForeignKeyClauseSyntax.Do {
        let token = state.take()
        
        switch token.kind {
        case .set:
            let token = state.take()
            switch token.kind {
            case .null: return .setNull
            case .default: return .setDefault
            default:
                state.diagnostics.add(.unexpectedToken(
                    of: token.kind,
                    expectedAnyOf: .null, .default,
                    at: token.location
                ))
                return .noAction
            }
        case .cascade:
            return .cascade
        case .restrict:
            return .restrict
        case .no:
            state.consume(.action)
            return .noAction
        default:
            state.diagnostics.add(.unexpectedToken(
                of: token.kind,
                expectedAnyOf: .set, .cascade, .restrict,
                at: token.location
            ))
            return .noAction
        }
    }
    
    /// https://www.sqlite.org/syntax/foreign-key-clause.html
    private static func foreignKeyClauseDeferrable(
        state: inout ParserState
    ) -> ForeignKeyClauseSyntax.Deferrable? {
        switch state.current.kind {
        case .initially:
            state.skip()
            let token = state.take()
            switch token.kind {
            case .deferred: return .initiallyDeferred
            case .immediate: return .initiallyImmediate
            default:
                state.diagnostics.add(.unexpectedToken(
                    of: token.kind,
                    expectedAnyOf: .deferred, .immediate,
                    at: token.location
                ))
                return .initiallyDeferred
            }
        default:
            return nil
        }
    }
    
    /// https://www.sqlite.org/lang_droptable.html
    static func dropTable(state: inout ParserState) -> DropTableStmtSyntax {
        let drop = state.take(.drop)
        state.consume(.table)
        
        let ifExists = ifExists(state: &state)
        
        let table = tableName(state: &state)
        return DropTableStmtSyntax(
            id: state.nextId(),
            ifExists: ifExists,
            tableName: table,
            location: state.location(from: drop)
        )
    }
    
    /// https://www.sqlite.org/lang_createtable.html
    static func createTrigger(state: inout ParserState) throws -> CreateTriggerStmtSyntax {
        let start = state.location
        state.consume(.create)
        let isTemporary = state.take(if: .temp) || state.take(if: .temporary)
        state.consume(.trigger)
        let ifNotExists = ifNotExists(state: &state)
        let (schema, trigger) = tableAndSchemaName(state: &state)
        
        let modifier: CreateTriggerStmtSyntax.Modifier?
        if state.take(if: .before) {
            modifier = .before
        } else if state.take(if: .after) {
            modifier = .after
        } else if state.take(if: .instead) {
            state.consume(.of)
            modifier = .insteadOf
        } else {
            modifier = nil
        }
        
        let action: CreateTriggerStmtSyntax.Action
        if state.take(if: .delete) {
            action = .delete
        } else if state.take(if: .insert) {
            action = .insert
        } else if state.take(if: .update) {
            if state.take(if: .of) {
                action = .update(columns: columnNameList(state: &state))
            } else {
                action = .update(columns: nil)
            }
        } else {
            action = .insert // Just default to insert so we can continue
            state.diagnostics.add(.init(
                "Expected 'DELETE', 'INSERT' or 'UPDATE'",
                at: state.current.location
            ))
        }
        
        state.consume(.on)
        
        let tableName = tableAndSchemaName(state: &state)
        
        if state.take(if: .for) {
            state.consume(.each)
            state.consume(.row)
        }
        
        let when: ExprSyntax?
        if state.take(if: .when) {
            when = try expr(state: &state)
        } else {
            when = nil
        }
        
        state.consume(.begin)
        let statements = stmts(state: &state, end: .end)
        state.consume(.end)
        
        return CreateTriggerStmtSyntax(
            id: state.nextId(),
            location: state.location(from: start),
            isTemporary: isTemporary,
            ifNotExists: ifNotExists,
            schemaName: schema,
            triggerName: trigger,
            modifier: modifier,
            action: action,
            tableSchemaName: tableName.schema,
            tableName: tableName.table,
            when: when,
            statements: statements
        )
    }
    
    /// https://www.sqlite.org/lang_droptrigger.html
    static func dropTrigger(state: inout ParserState) -> DropTriggerStmtSyntax {
        let start = state.location
        state.consume(.drop)
        state.consume(.trigger)
        let ifExists = ifExists(state: &state)
        let names = tableAndSchemaName(state: &state)
        return DropTriggerStmtSyntax(
            id: state.nextId(),
            location: state.location(from: start),
            ifExists: ifExists,
            schemaName: names.schema,
            triggerName: names.table
        )
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func expr(
        state: inout ParserState,
        precedence: Operator.Precedence = 0
    ) throws -> any ExprSyntax {
        var expr = try primaryExpr(state: &state, precedence: precedence)
        
        while true {
            // If the lhs was a column refernce with no table/schema and we are
            // at an open paren treat as a function call.
            if state.is(of: .openParen),
                let columnExpr = expr as? ColumnExprSyntax,
                case let .column(column) = columnExpr.column,
                columnExpr.schema == nil {
                let args = try parensOrEmpty(state: &state) { state in
                    // TODO: Validate it is an aggregate function
                    if state.current.kind == .all || state.current.kind == .distinct {
                        state.skip()
                    }
                    
                    return try commaDelimited(state: &state)  { try Parsers.expr(state: &$0) }
                }
                
                expr = FunctionExprSyntax(
                    id: state.nextId(),
                    table: columnExpr.table,
                    name: column,
                    args: args ?? [],
                    location: state.location(from: expr.location)
                )
            } else {
                guard let op = Operator.guess(for: state.current.kind, after: state.peek.kind),
                      op.precedence(usage: .infix) >= precedence
                else {
                    return expr
                }
                
                // The between operator is a different one. It doesnt act like a
                // normal infix expression. There are two rhs expressions for the
                // lower and upper bounds. Those need to be parsed individually
                //
                // TODO: Move this to the Infix Parser
                if op == .between || op == .not(.between) {
                    let op = Parsers.operator(state: &state)
                    assert(op.operator == .between || op.operator == .not(.between), "Guess cannot be wrong")
                    
                    // We need to dispatch the lower and upper bound expr's with a
                    // precedence above AND so the AND is not included in the expr.
                    // e.g. (a BETWEEN b AND C) not (a BETWEEN (b AND c))
                    let precAboveAnd = Operator.and.precedence(usage: .infix) + 1
                    let lowerBound = try Parsers.expr(state: &state, precedence: precAboveAnd)
                    state.consume(.and)
                    let upperBound = try Parsers.expr(state: &state, precedence: precAboveAnd)
                    expr = BetweenExprSyntax(
                        id: state.nextId(),
                        not: op.operator == .not(.between),
                        value: expr,
                        lower: lowerBound,
                        upper: upperBound
                    )
                } else {
                    expr = try infixExpr(state: &state, lhs: expr)
                }
            }
        }
        
        return expr
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func primaryExpr(
        state: inout ParserState,
        precedence: Operator.Precedence
    ) throws -> any ExprSyntax {
        switch state.current.kind {
        case .double, .string, .int, .hex, .currentDate, .currentTime, .currentTimestamp, .true, .false:
            return literal(state: &state)
        case .identifier, .star:
            return try columnExpr(state: &state, schema: nil, table: nil)
        case .questionMark, .colon, .dollarSign, .at:
            return bindParameter(state: &state)
        case .plus:
            let token = state.take()
            let op = OperatorSyntax(id: state.nextId(), operator: .plus, location: token.location)
            return try PrefixExprSyntax(id: state.nextId(), operator: op, rhs: expr(state: &state, precedence: precedence))
        case .tilde:
            let token = state.take()
            let op = OperatorSyntax(id: state.nextId(), operator: .tilde, location: token.location)
            return try PrefixExprSyntax(id: state.nextId(), operator: op, rhs: expr(state: &state, precedence: precedence))
        case .minus:
            let token = state.take()
            let op = OperatorSyntax(id: state.nextId(), operator: .minus, location: token.location)
            return try PrefixExprSyntax(id: state.nextId(), operator: op, rhs: expr(state: &state, precedence: precedence))
        case .null:
            let token = state.take()
            return LiteralExprSyntax(id: state.nextId(),kind: .null, location: token.location)
        case .openParen:
            let start = state.current.location
            let expr = try parens(state: &state) { state in
                try commaDelimited(state: &state) { try Parsers.expr(state: &$0) }
            }
            return GroupedExprSyntax(id: state.nextId(), exprs: expr, location: state.location(from: start))
        case .cast:
            let start = state.take()
            state.consume(.openParen)
            let expr = try expr(state: &state)
            state.consume(.as)
            let type = typeName(state: &state)
            state.consume(.closeParen)
            return CastExprSyntax(id: state.nextId(), expr: expr, ty: type, location: state.location(from: start.location))
        case .select:
            let select = try selectStmt(state: &state)
            return SelectExprSyntax(id: state.nextId(), select: select)
        case .exists:
            return try exists(state: &state, not: false, start: state.location)
        case .not where state.peek.kind == .exists:
            let start = state.take()
            return try exists(state: &state, not: true, start: start.location)
        case .case:
            let start = state.take()
            let `case` = try take(ifNot: .when, state: &state) { try expr(state: &$0) }
            
            var whenThens: [CaseWhenThenExprSyntax.WhenThen] = []
            while state.current.kind == .when {
                try whenThens.append(whenThen(state: &state))
            }
            
            let el: (any ExprSyntax)? = if state.take(if: .else) {
                try expr(state: &state)
            } else {
                nil
            }
            
            state.consume(.end)
            
            return CaseWhenThenExprSyntax(
                id: state.nextId(),
                case: `case`,
                whenThen: whenThens,
                else: el,
                location: state.location(from: start.location)
            )
        default:
            let tok = state.take()
            state.diagnostics.add(.init(
                "Expected expression, but got '\(tok.kind)' instead",
                at: state.location
            ))
            return InvalidExprSyntax(id: state.nextId(), location: tok.location)
        }
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func infixExpr(
        state: inout ParserState,
        lhs: any ExprSyntax
    ) throws -> any ExprSyntax {
        let op = Parsers.operator(state: &state)
        
        switch op.operator {
        case .isnull, .notnull, .notNull, .collate:
            return PostfixExprSyntax(id: state.nextId(), lhs: lhs, operator: op)
        default: break
        }
        
        let rhs = try expr(
            state: &state,
            precedence: op.operator.precedence(usage: .infix) + 1
        )
        
        return InfixExprSyntax(id: state.nextId(), lhs: lhs, operator: op, rhs: rhs)
    }

    static func exists(
        state: inout ParserState,
        not: Bool,
        start: SourceLocation
    ) throws -> ExistsExprSyntax {
        state.consume(.exists)
        let select = try parens(state: &state, value: selectStmt)
        return ExistsExprSyntax(
            id: state.nextId(),
            not: not,
            location: state.location(from: start),
            select: select
        )
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func columnExpr(
        state: inout ParserState,
        schema: IdentifierSyntax?,
        table: IdentifierSyntax?
    ) throws -> ColumnExprSyntax {
        switch state.current.kind {
        case .star:
            let star = state.take()
            return ColumnExprSyntax(
                id: state.nextId(),
                schema: schema,
                table: table,
                column: .all(star.location)
            )
        case .identifier:
            let ident = identifier(state: &state)
            
            if state.take(if: .dot) {
                return try columnExpr(state: &state, schema: table, table: ident)
            } else {
                return ColumnExprSyntax(
                    id: state.nextId(),
                    schema: schema,
                    table: table,
                    column: .column(ident)
                )
            }
        default:
            throw state.diagnostics.add(.init(
                "Unexpected token, expected * or an identifier",
                at: state.location
            ))
        }
    }
    
    /// https://www.sqlite.org/syntax/expr.html
    static func whenThen(state: inout ParserState) throws -> CaseWhenThenExprSyntax.WhenThen {
        state.consume(.when)
        let when = try expr(state: &state)
        state.consume(.then)
        let then = try expr(state: &state)
        return CaseWhenThenExprSyntax.WhenThen(when: when, then: then)
    }
    
    /// https://www.sqlite.org/c3ref/bind_blob.html
    static func bindParameter(state: inout ParserState) -> BindParameterSyntax {
        let token = state.take()
        let kind: BindParameterSyntax.Kind
        
        switch token.kind {
        case .questionMark:
            if case let .int(n) = state.current.kind {
                state.skip()
                kind = .number(n)
            } else {
                kind = .questionMark
            }
        case .colon:
            kind = .colon(identifierAllowingKeywords(state: &state))
        case .at:
            kind = .at(identifierAllowingKeywords(state: &state))
        case .dollarSign:
            let segments = delimited(by: .colon, and: .colon, state: &state, element: identifier)
            let suffix = take(if: .openParen, state: &state) { state in
                parens(state: &state, value: identifier)
            }
            kind = .tcl(segments, suffix: suffix)
        default:
            state.diagnostics.add(.init("Invalid bind parameter", at: token.location))
            return BindParameterSyntax(
                id: state.nextId(),
                kind: .questionMark,
                index: -1,
                location: token.location
            )
        }
        
        return BindParameterSyntax(
            id: state.nextId(),
            kind: kind,
            index: state.indexForParam(kind),
            location: state.location(from: token.location)
        )
    }
    
    static func `operator`(state: inout ParserState) -> OperatorSyntax {
        guard let op = Operator.guess(
            for: state.current.kind,
            after: state.peek.kind
        ) else {
            state.diagnostics.add(.init("Invalid operator", at: state.location))
            return .init(id: state.nextId(), operator: .plus, location: state.current.location)
        }
        
        let start = state.current.location
        op.skip(state: &state)
        
        switch op {
        case .tilde, .collate, .concat, .arrow, .doubleArrow, .multiply, .divide,
             .mod, .plus, .minus, .bitwiseAnd, .bitwuseOr, .shl, .shr, .escape,
             .lt, .gt, .lte, .gte, .eq, .eq2, .neq, .neq2, .match, .like, .regexp,
             .glob, .or, .and, .between, .not, .in, .isnull, .notnull, .notNull, .isDistinctFrom:
            return OperatorSyntax(id: state.nextId(), operator: op, location: start)
        case .is:
            if state.take(if: .distinct) {
                let from = state.take(.from)
                return OperatorSyntax(id: state.nextId(), operator: .isDistinctFrom, location: start.spanning(from.location))
            } else {
                return OperatorSyntax(id: state.nextId(), operator: .is, location: start)
            }
        case .isNot:
            if state.take(if: .distinct) {
                let from = state.take(.from)
                return OperatorSyntax(
                    id: state.nextId(),
                    operator: .isNotDistinctFrom,
                    location: start.spanning(from.location)
                )
            } else {
                return OperatorSyntax(
                    id: state.nextId(),
                    operator: .isNot,
                    location: start.spanning(state.current.location)
                )
            }
        case .isNotDistinctFrom:
            fatalError("guess will not return these since the look ahead is only 2")
        }
    }
    
    /// This is a custom thing, `DEFINE QUERY ...`
    static func definition(state: inout ParserState) throws -> StmtSyntax {
        let define = state.take(.define)
        state.skip(.query)
        let name = identifier(state: &state)
        
        let params: [Substring: IdentifierSyntax]? = take(if: .openParen, state: &state) { state in
            parens(state: &state) { state in
                delimited(by: .comma, state: &state, reduceInto: [:]) { params, param in
                    params[param.name.value] = param.value
                } element: { state in
                    let name = identifier(state: &state)
                    state.skip(.colon)
                    let value = identifier(state: &state)
                    return (name: name, value: value)
                }
            }
        }
        
        state.skip(.as)
        let stmt = try stmt(state: &state)
        
        return QueryDefinitionStmtSyntax(
            id: state.nextId(),
            name: name,
            input: params?["input"],
            output: params?["output"],
            statement: stmt,
            location: define.location.spanning(state.current.location)
        )
    }
    
    static func take<Output>(
        if kind: Token.Kind,
        state: inout ParserState,
        parse: (inout ParserState) throws -> Output
    ) rethrows -> Output? {
        guard state.current.kind == kind else { return nil }
        return try parse(&state)
    }
    
    static func take<Output>(
        ifNot kind: Token.Kind,
        state: inout ParserState,
        parse: (inout ParserState) throws -> Output
    ) rethrows -> Output? {
        guard state.current.kind != kind else { return nil }
        return try parse(&state)
    }
    
    static func commaDelimited<Element>(
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) rethrows -> [Element] {
        return try delimited(by: .comma, state: &state, element: element)
    }
    
    static func commaDelimitedInParens<Element>(
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) rethrows -> [Element] {
        return try parens(state: &state) { state in
            try commaDelimited(state: &state, element: element)
        }
    }
    
    static func delimited<Element>(
        by kind: Token.Kind,
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) rethrows -> [Element] {
        var elements: [Element] = []
        
        repeat {
            try elements.append(element(&state))
        } while state.take(if: kind)
        
        return elements
    }
    
    static func delimited<Element>(
        by kind: Token.Kind,
        and otherKind: Token.Kind,
        state: inout ParserState,
        element: (inout ParserState) throws -> Element
    ) rethrows -> [Element] {
        var elements: [Element] = []
        
        repeat {
            try elements.append(element(&state))
        } while state.take(if: kind, and: otherKind)
        
        return elements
    }
    
    static func delimited<Element, Output>(
        by kind: Token.Kind,
        state: inout ParserState,
        reduceInto elements: Output,
        reduce: (inout Output, Element) -> Void,
        element: (inout ParserState) throws -> Element
    ) rethrows -> Output {
        var elements = elements

        repeat {
            try reduce(&elements, element(&state))
        } while state.take(if: kind)
        
        return elements
    }
    
    /// Parses a value in between parenthesis. Assumes the value exists within
    /// the parenthesis.
    static func parens<Value>(
        state: inout ParserState,
        value: (inout ParserState) throws -> Value
    ) rethrows -> Value {
        state.consume(.openParen)
        let value = try value(&state)
        state.consume(.closeParen)
        return value
    }
    
    /// Just like `parens` but allows for an empty set of parens
    static func parensOrEmpty<Value>(
        state: inout ParserState,
        value: (inout ParserState) throws -> Value
    ) rethrows -> Value? {
        try parens(state: &state) { state in
            guard state.current.kind != .closeParen else { return nil }
            return try value(&state)
        }
    }
    
    static func identifier(
        state: inout ParserState
    ) -> IdentifierSyntax {
        let token = state.take()
        
        guard case let .identifier(ident) = token.kind else {
            state.diagnostics.add(.init("Expected identifier", at: token.location))
            return IdentifierSyntax(value: "<<error>>", location: token.location)
        }
        
        return IdentifierSyntax(value: ident, location: token.location)
    }
    
    /// So this is to handle a weird edge case. SQLite apparently allows keywords
    /// to be used as parameter names.
    static func identifierAllowingKeywords(
        state: inout ParserState
    ) -> IdentifierSyntax {
        let token = state.take()
        
        if case let .identifier(ident) = token.kind {
            return IdentifierSyntax(value: ident, location: token.location)
        }
        
        // Since this is kind of edge casey instead of making all
        // keywords just Token.identifier() just regrabbing the source.
        // Would hate to hold on to every word in the source in a substring
        // when its really only needed for this.
        let rawValue = state.lexer.source[token.location.range]
        let isKeyword = Token.keywords[rawValue.uppercased()] != nil
        
        // If its not a keyword its likely an operator or something which we
        // should not allow
        guard isKeyword else {
            state.diagnostics.add(.init("Expected identifier", at: token.location))
            return IdentifierSyntax(value: "<<error>>", location: token.location)
        }
        
        return IdentifierSyntax(value: rawValue, location: token.location)
    }
    
    /// https://www.sqlite.org/syntax/numeric-literal.html
    static func numericLiteral(state: inout ParserState) -> NumericSyntax {
        let token = state.take()
        
        switch token.kind {
        case let .double(value):
            return value
        case let .int(value):
            return Double(value)
        case let .hex(value):
            return Double(value)
        default:
            state.diagnostics.add(.init("Expected numeric", at: token.location))
            return 0
        }
    }
    
    /// https://www.sqlite.org/syntax/signed-number.html
    static func signedNumber(state: inout ParserState) -> SignedNumberSyntax {
        let token = state.take()
        
        switch token.kind {
        case let .double(value):
            return value
        case let .int(value):
            return SignedNumberSyntax(value)
        case let .hex(value):
            return SignedNumberSyntax(value)
        case .plus:
            return numericLiteral(state: &state)
        case .minus:
            return -numericLiteral(state: &state)
        default:
            state.diagnostics.add(.init("Expected signed number", at: token.location))
            return 0
        }
    }
    
    static func literal(state: inout ParserState) -> LiteralExprSyntax {
        let token = state.take()
        
        let kind: LiteralExprSyntax.Kind
        switch token.kind {
        case let .double(value):
            kind = .numeric(value, isInt: false)
        case let .int(value):
            kind = .numeric(Double(value), isInt: true)
        case let .hex(value):
            kind = .numeric(Double(value), isInt: true)
        case let .string(value):
            kind = .string(value)
        case .true:
            kind = .true
        case .false:
            kind = .false
        case .currentDate:
            kind = .currentDate
        case .currentTime:
            kind = .currentTime
        case .currentTimestamp:
            kind = .currentTimestamp
        default:
            state.diagnostics.add(.init("Invalid literal", at: token.location))
            kind = .invalid
        }
        
        return LiteralExprSyntax(id: state.nextId(), kind: kind, location: token.location)
    }
    
    static func order(state: inout ParserState) -> OrderSyntax? {
        switch state.current.kind {
        case .asc:
            let token = state.take()
            return OrderSyntax(id: state.nextId(), kind: .asc, location: token.location)
        case .desc:
            let token = state.take()
            return OrderSyntax(id: state.nextId(), kind: .desc, location: token.location)
        default:
            return nil
        }
    }
    
    /// Called on an unrecoverable error. Most errors we can return some value that allows the
    /// parser to continue within the statement. But some cases we cannot return any value since
    /// and guess of what they were trying to do would lead to even more erroneous errors.
    ///
    /// This just attempts to skip to the end of the current statement
    static func recover(state: inout ParserState, toNext kind: Token.Kind = .semiColon) {
        while state.current.kind != kind, state.current.kind != .eof {
            state.skip()
        }
    }
}

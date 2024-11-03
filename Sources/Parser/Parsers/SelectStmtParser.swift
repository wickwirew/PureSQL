//
//  SelectStmtParser.swift
//
//
//  Created by Wes Wickwire on 10/14/24.
//

import Schema

struct SelectStmtParser: Parser {
    func parse(state: inout ParserState) throws -> SelectStmt {
        let cte: CommonTableExpression?
        let cteRecursive: Bool
        if try state.take(if: .with) {
            cteRecursive = try state.take(if: .recursive)
            cte = try CommonTableExprParser()
                .parse(state: &state)
        } else {
            cteRecursive = false
            cte = nil
        }
        
        let selects = try SelectCoreParser()
            .collect(if: [.select, .values], checkFirst: true)
            .parse(state: &state)
        
        let orderBy = try parseOrderBy(state: &state)
        let limit = try parseLimit(state: &state)
        
        return SelectStmt(
            cte: cte,
            cteRecursive: cteRecursive,
            selects: .single(selects.first!),
            orderBy: orderBy,
            limit: limit
        )
    }
    
    func parseOrderBy(state: inout ParserState) throws -> [OrderingTerm] {
        guard try state.take(if: .order) else { return [] }
        try state.consume(.by)
        
        return try OrderingTermParser()
            .commaSeparated()
            .parse(state: &state)
    }
    
    func parseLimit(state: inout ParserState) throws -> SelectStmt.Limit? {
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
}

struct OrderingTermParser: Parser {
    func parse(state: inout ParserState) throws -> OrderingTerm {
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
}

extension OrderingTerm: Parsable {
    static let parser = OrderingTermParser()
}

struct SelectCoreParser: Parser {
    func parse(state: inout ParserState) throws -> SelectCore {
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
        
        let columns = try ResultColumnParser()
            .commaSeparated()
            .parse(state: &state)
        
        let from = try parseFrom(state: &state)
        
        let `where` = try ExprParser()
            .take(if: .where, consume: true)
            .parse(state: &state)
        
        let groupBy = try parseGroupBy(state: &state)
        
        let windows = try WindowParser()
            .commaSeparated()
            .take(if: .window, consume: true)
            .parse(state: &state)
        
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
    
    private func parseFrom(state: inout ParserState) throws -> SelectCore.From? {
        let output = try JoinClauseOrTableOrSubqueryParser()
            .take(if: .from, consume: true)
            .parse(state: &state)
        
        switch output {
        case .join(let joinClause):
            return .join(joinClause)
        case .tableOrSubqueries(let tableOrSubqueries):
            return .tableOrSubqueries(tableOrSubqueries)
        case nil:
            return nil
        }
    }
    
    private func parseGroupBy(state: inout ParserState) throws -> SelectCore.GroupBy? {
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
    
    private struct WindowParser: Parser {
        func parse(state: inout ParserState) throws -> SelectCore.Window {
            let name = try SymbolParser().parse(state: &state)
            try state.consume(.as)
            let window = try WindowDefinitionParser().parse(state: &state)
            return SelectCore.Window(name: name, window: window)
        }
    }
}

/// This isnt necessarily a part of the grammar, but there is abiguity when starting
/// a list of tables/subqueries or join clauses. Most likely the later but the the logic
/// is duplicated in SQLites docs for the parsing so this just centralizes it.
struct JoinClauseOrTableOrSubqueryParser: Parser {
    enum Output: Equatable {
        case join(JoinClause)
        case tableOrSubqueries([TableOrSubquery])
    }
    
    func parse(state: inout ParserState) throws -> Output {
        // Both begin with a table or subquery
        let tableOrSubquery = try TableOrSubqueryParser()
            .parse(state: &state)
        
        if state.current.kind == .comma {
            try state.skip()
            
            let more = try TableOrSubqueryParser()
                .commaSeparated()
                .parse(state: &state)
            
            return .tableOrSubqueries([tableOrSubquery] + more)
        } else {
            // No comma, we are in join clause
            return .join(
                try JoinClauseParser(tableOrSubquery: tableOrSubquery)
                    .parse(state: &state)
            )
        }
    }
}

struct ResultColumnParser: Parser {
    func parse(state: inout ParserState) throws -> ResultColumn {
        switch state.current.kind {
        case .star:
            try state.skip()
            return .all(table: nil)
        case .symbol(let table) where state.peek.kind == .dot && state.peek2.kind == .star:
            let table = Identifier(name: table, range: state.current.range)
            try state.skip()
            try state.consume(.dot)
            return .all(table: table)
        default:
            let expr = try ExprParser()
                .parse(state: &state)
            
            if try state.take(if: .as) {
                let alias = try SymbolParser().parse(state: &state)
                return .expr(expr, as: alias)
            } else if case let .symbol(alias) = state.current.kind {
                let alias = Identifier(name: alias, range: state.current.range)
                try state.skip()
                return .expr(expr, as: alias)
            } else {
                return .expr(expr, as: nil)
            }
        }
    }
}

extension ResultColumn: Parsable {
    static let parser = ResultColumnParser()
}

struct TableOrSubqueryParser: Parser {
    func parse(state: inout ParserState) throws -> TableOrSubquery {
        switch state.current.kind {
        case .symbol:
            let (schema, table) = try TableAndSchemaNameParser()
                .parse(state: &state)
            
            if state.current.kind == .openParen {
                let args = try ExprParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
                
                let alias = try parseAlias(state: &state)
                
                return .tableFunction(schema: schema, table: table, args: args, alias: alias)
            } else {
                let alias = try parseAlias(state: &state)
                
                let indexedBy: Identifier?
                switch state.current.kind {
                case .indexed:
                    try state.skip()
                    try state.consume(.by)
                    indexedBy = try SymbolParser().parse(state: &state)
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
                let subquery = try SelectStmtParser()
                    .inParenthesis()
                    .parse(state: &state)
                
                let alias = try parseAlias(state: &state)
                return .subquery(subquery, alias: alias)
            } else {
                let result = try JoinClauseOrTableOrSubqueryParser()
                    .inParenthesis()
                    .parse(state: &state)
                
                switch result {
                case .join(let joinClause):
                    return .join(joinClause)
                case .tableOrSubqueries(let table):
                    let alias = try parseAlias(state: &state)
                    return .subTableOrSubqueries(table, alias: alias)
                }
            }
        default:
            throw ParsingError(description: "Expected table or subquery", sourceRange: state.current.range)
        }
    }
    
    private func parseAlias(state: inout ParserState) throws -> Identifier? {
        if try state.take(if: .as) {
            return try SymbolParser().parse(state: &state)
        } else if case .symbol(let alias) = state.current.kind {
            let alias = Identifier(name: alias, range: state.current.range)
            try state.skip()
            return alias
        } else {
            return nil
        }
    }
}

extension TableOrSubquery: Parsable {
    static let parser = TableOrSubqueryParser()
}

struct JoinClauseParser: Parser {
    let tableOrSubquery: TableOrSubquery
    
    func parse(state: inout ParserState) throws -> JoinClause {
        let joins = try JoinParser()
            .collect(if: [.natural, .comma, .left, .right, .full, .inner, .cross, .join], checkFirst: true)
            .parse(state: &state)
        
        return JoinClause(tableOrSubquery: tableOrSubquery, joins: joins)
    }
    
    private struct JoinParser: Parser {
        func parse(state: inout ParserState) throws -> JoinClause.Join {
            let op = try JoinOperatorParser()
                .parse(state: &state)
            
            let tableOrSubquery = try TableOrSubqueryParser()
                .parse(state: &state)
            
            let constraint = try JoinConstraintParser().parse(state: &state)
            
            return JoinClause.Join(
                op: op,
                tableOrSubquery: tableOrSubquery,
                constraint: constraint
            )
        }
    }
}

extension JoinClause: Parsable {
    static let parser = JoinClauseOrTableOrSubqueryParser()
}

struct WindowDefinitionParser: Parser {
    func parse(state: inout ParserState) throws -> WindowDefinition {
        fatalError()
    }
}

struct JoinOperatorParser: Parser {
    func parse(state: inout ParserState) throws -> JoinOperator {
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
}

extension JoinOperator: Parsable {
    static let parser = JoinOperatorParser()
}

struct JoinConstraintParser: Parser {
    func parse(state: inout ParserState) throws -> JoinConstraint {
        if try state.take(if: .on) {
            return .on(
                try ExprParser()
                    .parse(state: &state)
            )
        } else if try state.take(if: .using) {
            return .using(
                try SymbolParser()
                    .commaSeparated()
                    .inParenthesis()
                    .parse(state: &state)
            )
        } else {
            return .none
        }
    }
}

struct CommonTableExprParser: Parser {
    func parse(state: inout ParserState) throws -> CommonTableExpression {
        let table = try SymbolParser().parse(state: &state)
        
        let columns = try SymbolParser()
            .commaSeparated()
            .inParenthesis()
            .take(if: .openParen)
            .parse(state: &state)
        
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
        
        let select = try SelectStmtParser()
            .inParenthesis()
            .parse(state: &state)
        
        return CommonTableExpression(
            table: table,
            columns: columns ?? [],
            materialized: materialized,
            select: select
        )
    }
}

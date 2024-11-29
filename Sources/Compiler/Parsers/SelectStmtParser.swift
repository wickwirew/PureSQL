//
//  SelectStmtParser.swift
//
//
//  Created by Wes Wickwire on 10/14/24.
//

struct SelectStmtParser: Parser {
    func parse(state: inout ParserState) throws -> SelectStmt {
        let cte: CommonTableExpression?
        let cteRecursive: Bool
        if try state.take(if: .with) {
            cteRecursive = try state.take(if: .recursive)
            cte = try Parsers.cte(state: &state)
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
        
        let columns = try Parsers.commaDelimited(state: &state, element: Parsers.resultColumn)
        
        let from = try Parsers.from(state: &state)
        
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
            let name = try IdentifierParser().parse(state: &state)
            try state.consume(.as)
            let window = try WindowDefinitionParser().parse(state: &state)
            return SelectCore.Window(name: name, window: window)
        }
    }
}

struct WindowDefinitionParser: Parser {
    func parse(state: inout ParserState) throws -> WindowDefinition {
        fatalError()
    }
}

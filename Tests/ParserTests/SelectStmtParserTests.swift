//
//  SelectStmtParserTests.swift
//
//
//  Created by Wes Wickwire on 10/15/24.
//

import XCTest
import Schema

@testable import Parser

class SelectStmtParserTests: XCTestCase {
    private func parserState(_ source: String) throws -> ParserState {
        return try ParserState(Lexer(source: source))
    }
    
    private func execute<P: Parser>(parser: P, source: String) throws -> P.Output {
        var state = try parserState(source)
        return try parser.parse(state: &state)
    }
}

extension SelectStmtParserTests {
    func testSimpleSelect() throws {
        let stmt = try execute(parser: SelectStmtParser(), source: "SELECT * FROM foo")
        
        let expected = SelectStmt(
            select: SelectCore.Select(
                distinct: false,
                columns: [.all(table: nil)],
                from: SelectCore.From(table: "foo"),
                where: nil,
                groupBy: nil,
                windows: []
            )
        )
        
        XCTAssertEqual(stmt, expected)
    }
}

// MARK: - JoinConstraint

extension SelectStmtParserTests {
    func testJoinConstraintOnExpression() throws {
        guard case .on(.literal(let literal)) = try execute(parser: JoinConstraintParser(), source: "ON 1") else {
            return XCTFail()
        }
        
        XCTAssertEqual(literal.kind, .numeric(1, isInt: true))
    }
    
    func testJoinConstraintUsing() {
        XCTAssertEqual(.using(["id"]), try execute(parser: JoinConstraintParser(), source: "USING (id)"))
        
        XCTAssertEqual(.using(["foo", "bar"]), try execute(parser: JoinConstraintParser(), source: "USING (foo, bar)"))
    }
    
    func testJoinConstraintNone() {
        XCTAssertEqual(.none, try execute(parser: JoinConstraintParser(), source: ""))
    }
}

// MARK: - CTE

extension SelectStmtParserTests {
    func testCommonTableExpression() {
        XCTAssertEqual(
            CommonTableExpression(
                table: "foo",
                columns: ["id", "name"],
                select: SelectStmt(
                    select: SelectCore.Select(
                        columns: [.all(table: nil)],
                        from: SelectCore.From(table: "bar")
                    )
                )
            ),
            try execute(
                parser: CommonTableExprParser(),
                source: "foo (id, name) AS (SELECT * FROM bar)"
            )
        )
    }
}

// MARK: - Join Operator

extension SelectStmtParserTests {
    func testNaturalJoinOperator() {
        XCTAssertEqual(.natural, try JoinOperator(sql: "NATURAL JOIN"))
        XCTAssertEqual(.left(natural: true), try JoinOperator(sql: "NATURAL LEFT JOIN"))
        XCTAssertEqual(.left(natural: true, outer: true), try JoinOperator(sql: "NATURAL LEFT OUTER JOIN"))
        XCTAssertEqual(.right(natural: true), try JoinOperator(sql: "NATURAL RIGHT JOIN"))
        XCTAssertEqual(.full(natural: true), try JoinOperator(sql: "NATURAL FULL JOIN"))
        XCTAssertEqual(.inner(natural: true), try JoinOperator(sql: "NATURAL INNER JOIN"))
    }
    
    func testJoinOperator() {
        XCTAssertEqual(.left(), try JoinOperator(sql: "LEFT JOIN"))
        XCTAssertEqual(.left(outer: true), try JoinOperator(sql: "LEFT OUTER JOIN"))
        XCTAssertEqual(.right(), try JoinOperator(sql: "RIGHT JOIN"))
        XCTAssertEqual(.full(), try JoinOperator(sql: "FULL JOIN"))
        XCTAssertEqual(.inner(), try JoinOperator(sql: "INNER JOIN"))
    }
    
    func testCrossJoinOperator() {
        XCTAssertEqual(.comma, try JoinOperator(sql: ","))
        XCTAssertEqual(.cross, try JoinOperator(sql: "CROSS JOIN"))
    }
}

// MARK: - Ordering Term

//extension SelectStmtParserTests {
//    func testOrderingTermOnlyExpr() {
//        XCTAssertEqual(OrderingTerm(expr: .literal(1), order: .asc, nulls: nil), try OrderingTerm(sql: "1"))
//        XCTAssertEqual(OrderingTerm(expr: .literal(1), order: .asc, nulls: nil), try OrderingTerm(sql: "1 ASC"))
//        XCTAssertEqual(OrderingTerm(expr: .literal(1), order: .desc, nulls: nil), try OrderingTerm(sql: "1 DESC"))
//    }
//    
//    func testOrderingTermExprWithCollation() {
//        let collate: Expression = .postfix(PostfixExpr(lhs: .literal(1), operator: .collate("NOCASE")))
//        XCTAssertEqual(OrderingTerm(expr: collate, order: .asc, nulls: nil), try OrderingTerm(sql: "1 COLLATE NOCASE"))
//        XCTAssertEqual(OrderingTerm(expr: collate, order: .asc, nulls: nil), try OrderingTerm(sql: "1 COLLATE NOCASE ASC"))
//        XCTAssertEqual(OrderingTerm(expr: collate, order: .desc, nulls: nil), try OrderingTerm(sql: "1 COLLATE NOCASE DESC"))
//    }
//    
//    func testOrderingTermOnlyNulls() {
//        XCTAssertEqual(OrderingTerm(expr: .literal(1), order: .asc, nulls: .first), try OrderingTerm(sql: "1 NULLS FIRST"))
//        XCTAssertEqual(OrderingTerm(expr: .literal(1), order: .asc, nulls: .last), try OrderingTerm(sql: "1 NULLS LAST"))
//    }
//}

// MARK: - ResultColumn

extension SelectStmtParserTests {
    func testResultColumnAll() {
        XCTAssertEqual(.all(table: nil), try ResultColumn(sql: "*"))
    }
    
    func testResultColumnAllFromTable() {
        XCTAssertEqual(.all(table: "foo"), try ResultColumn(sql: "foo.*"))
    }
    
    func testResultColumnExpr() throws {
        guard case let .expr(.literal(expr), alias) = try ResultColumn(sql: "1") else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(expr.kind, LiteralExpr.Kind.numeric(1, isInt: true))
        XCTAssertNil(alias)
    }
    
    func testResultColumnExprWithAlias() throws {
        guard case let .expr(.literal(expr), alias) = try ResultColumn(sql: "1 AS one") else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(expr.kind, LiteralExpr.Kind.numeric(1, isInt: true))
        XCTAssertEqual(alias?.name, "one")
    }
    
    func testResultColumnExprWithAliasMissingAs() throws {
        guard case let .expr(.literal(expr), alias) = try ResultColumn(sql: "1 one") else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(expr.kind, LiteralExpr.Kind.numeric(1, isInt: true))
        XCTAssertEqual(alias?.name, "one")
    }
}

// MARK: - TableOrSubquery

extension SelectStmtParserTests {
    func testTableOrSubquery() {
        XCTAssertEqual(TableOrSubquery(table: "foo"), try TableOrSubquery(sql: "foo"))
        XCTAssertEqual(TableOrSubquery(schema: "foo", table: "bar"), try TableOrSubquery(sql: "foo.bar"))
        XCTAssertEqual(TableOrSubquery(schema: "foo", table: "bar", alias: "baz"), try TableOrSubquery(sql: "foo.bar AS baz"))
        XCTAssertEqual(TableOrSubquery(schema: "foo", table: "bar", alias: "baz", indexedBy: "qux"), try TableOrSubquery(sql: "foo.bar AS baz INDEXED BY qux"))
        XCTAssertEqual(TableOrSubquery(schema: "foo", table: "bar", alias: "baz", indexedBy: nil), try TableOrSubquery(sql: "foo.bar AS baz NOT INDEXED"))
    }
    
//    func testTableOrSubqueryTableFunction() {
//        XCTAssertEqual(
//            .tableFunction(schema: nil, table: "foo", args: [.literal(1)], alias: nil),
//            try TableOrSubquery(sql: "foo(1)")
//        )
//        
//        XCTAssertEqual(
//            .tableFunction(schema: nil, table: "foo", args: [.literal(1)], alias: "bar"),
//            try TableOrSubquery(sql: "foo(1) AS bar")
//        )
//    }
    
    func testTableOrSubqueryTable() {
        XCTAssertEqual(
            TableOrSubquery.subTableOrSubqueries([
                TableOrSubquery(table: "foo"),
                TableOrSubquery(table: "bar"),
            ], alias: nil),
            try TableOrSubquery(sql: "(foo, bar)")
        )
        
        XCTAssertEqual(
            TableOrSubquery.subTableOrSubqueries([
                TableOrSubquery(table: "foo"),
                TableOrSubquery(table: "bar"),
            ], alias: "qux"),
            try TableOrSubquery(sql: "(foo, bar) AS qux")
        )
        
        XCTAssertEqual(
            TableOrSubquery.subTableOrSubqueries([
                TableOrSubquery(table: "foo"),
                TableOrSubquery(table: "bar"),
            ], alias: "qux"),
            try TableOrSubquery(sql: "(foo, bar) qux")
        )
    }
    
    func testTableOrSubqueryDefaultsToJoinClauseWhenSingleTable() {
        XCTAssertEqual(
            TableOrSubquery.join(JoinClause(table: "foo")),
            try TableOrSubquery(sql: "(foo)")
        )
    }
    
    func testTableOrSubqueryoJoinClause() {
        XCTAssertEqual(
            TableOrSubquery.join(JoinClause(table: "foo", joins: [.init(op: .inner(natural: false), tableOrSubquery: .init(table: "bar"), constraint: .none)])),
            try TableOrSubquery(sql: "(foo inner join bar)")
        )
    }
}

// MARK: - JoinClause

extension SelectStmtParserTests {
    func testJoinClauseSingleJoin() {
        XCTAssertEqual(
            .join(JoinClause(table: "foo", joins: [
                JoinClause.Join(op: .inner(natural: false), tableOrSubquery: .init(table: "bar"), constraint: .none),
            ])),
            try JoinClauseOrTableOrSubqueryParser().parse("foo INNER JOIN bar")
        )
    }
    
    func testJoinClauseManyJoins() {
        XCTAssertEqual(
            .join(JoinClause(table: "foo", joins: [
                JoinClause.Join(op: .inner(natural: false), tableOrSubquery: .init(table: "bar"), constraint: .none),
                JoinClause.Join(op: .left(natural: false), tableOrSubquery: .init(table: "baz"), constraint: .none),
            ])),
            try JoinClauseOrTableOrSubqueryParser().parse("foo INNER JOIN bar LEFT JOIN baz")
        )
    }
    
//    func testJoinClauseWithConstraints() {
//        XCTAssertEqual(
//            .join(JoinClause(table: "foo", joins: [
//                JoinClause.Join(op: .inner(natural: false), tableOrSubquery: .init(table: "bar"), constraint: .on(.literal(1))),
//            ])),
//            try JoinClauseOrTableOrSubqueryParser().parse("foo INNER JOIN bar ON 1")
//        )
//    }
    
    func testJoinClauseManyTables() {
        XCTAssertEqual(
            .join(JoinClause(table: "foo", joins: [
                JoinClause.Join(
                    op: .inner(natural: false),
                    tableOrSubquery: .subTableOrSubqueries([.init(table: "bar"), .init(table: "baz")], alias: nil),
                    constraint: .none
                )
            ])),
            try JoinClauseOrTableOrSubqueryParser().parse("foo INNER JOIN (bar, baz)")
        )
    }
}

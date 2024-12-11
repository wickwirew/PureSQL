//
//  ParserTests.swift
//
//
//  Created by Wes Wickwire on 10/9/24.
//

import XCTest

@testable import Compiler

/// Just tests for the smaller, less complex parsers that dont really need their own file.
final class ParserTests: XCTestCase {
    func testTableOptions() throws {
        try check(sqlFile: "TableOptions", parser: Parsers.tableOptions)
    }
    
    func testConflictClause() throws {
        try check(sqlFile: "ConflictClause", parser: Parsers.conflictClause, dump: true)
    }
    
    func testForeignKeyClause() throws {
        try check(sqlFile: "ForeignKeyClause", parser: Parsers.foreignKeyClause)
    }
    
    func testOrder() throws {
        try check(sqlFile: "Order", parser: Parsers.order)
    }
    
    func testColumnConstraint() throws {
        try check(sqlFile: "ColumnConstraint", parser: { Parsers.columnConstraint(state: &$0) })
    }
    
    func testColumnDefinition() throws {
        try check(sqlFile: "ColumnDefinition", parser: Parsers.columnDef)
    }
    
    func testAlterTable() throws {
        try check(sqlFile: "AlterTable", parser: Parsers.alterStmt)
    }
    
    func testSignedNumber() throws {
        try check(sqlFile: "SignedNumber", parser: Parsers.signedNumber)
    }
    
    func testTypeName() throws {
        try check(sqlFile: "TypeName", parser: Parsers.typeName)
    }
    
    func testCreateTable() throws {
        try check(sqlFile: "CreateTable", parser: Parsers.createTableStmt)
    }
    
    func testBindParameter() throws {
        try check(sqlFile: "BindParameter", parser: Parsers.bindParameter)
    }
    
    func testOpertators() throws {
        try check(sqlFile: "Operators", parser: Parsers.operator)
    }
    
    func testExpression() throws {
        try check(sqlFile: "Expression", parser: { Parsers.expr(state: &$0) })
    }
    
    func testSelectStmt() throws {
        try check(sqlFile: "SelectStmt", parser: Parsers.selectStmt)
    }
    
    func testJoinConstraint() throws {
        try check(sqlFile: "JoinConstraint", parser: Parsers.joinConstraint)
    }
    
    func testCommonTableExpression() throws {
        try check(sqlFile: "CommonTableExpression", parser: Parsers.cte)
    }
    
    func testJoinOperator() throws {
        try check(sqlFile: "JoinOperator", parser: Parsers.joinOperator)
    }
    
    func testOrderingTerm() throws {
        try check(sqlFile: "OrderingTerm", parser: Parsers.orderingTerm)
    }
    
    func testResultColumn() throws {
        try check(sqlFile: "ResultColumn", parser: Parsers.resultColumn)
    }
    
    func testTableOrSubquery() throws {
        try check(sqlFile: "TableOrSubquery", parser: Parsers.tableOrSubquery)
    }
    
    func testJoinClause() throws {
        try check(sqlFile: "JoinClause", parser: Parsers.joinClauseOrTableOrSubqueries)
    }
    
    func testInsertStmt() throws {
        try check(sqlFile: "InsertStmt", parser: Parsers.insertStmt)
    }
    
    func testUpdateStmt() throws {
        try check(sqlFile: "UpdateStmt", parser: Parsers.updateStmt)
    }
}

func check<Output>(
    sqlFile: String,
    parser: (inout ParserState) throws -> Output,
    prefix: String = "CHECK",
    dump: Bool = false,
    file: StaticString = #filePath,
    line: UInt = #line
) throws {
    try check(
        sqlFile: sqlFile,
        parse: { contents in
            var state = ParserState(Lexer(source: contents))
            var lines: [Output] = []
            
            while state.current.kind != .eof {
                repeat {
                    try lines.append(parser(&state))
                } while state.take(if: .semiColon) && state.current.kind != .eof
            }
            
            return lines
        },
        prefix: prefix,
        dump: dump,
        file: file,
        line: line
    )
}

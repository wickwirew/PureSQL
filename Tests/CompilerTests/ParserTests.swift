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
        try check(sqlFile: "ParseTableOptions", parser: Parsers.tableOptions)
    }
    
    func testConflictClause() throws {
        try check(sqlFile: "ParseConflictClause", parser: Parsers.conflictClause)
    }
    
    func testForeignKeyClause() throws {
        try check(sqlFile: "ParseForeignKeyClause", parser: Parsers.foreignKeyClause)
    }
    
    func testOrder() throws {
        try check(sqlFile: "ParseOrder", parser: Parsers.order)
    }
    
    func testColumnConstraint() throws {
        try check(sqlFile: "ParseColumnConstraint", parser: { try Parsers.columnConstraint(state: &$0) })
    }
    
    func testColumnDefinition() throws {
        try check(sqlFile: "ParseColumnDefinition", parser: Parsers.columnDef)
    }
    
    func testAlterTable() throws {
        try check(sqlFile: "ParseAlterTable", parser: Parsers.alterStmt)
    }
    
    func testSignedNumber() throws {
        try check(sqlFile: "ParseSignedNumber", parser: Parsers.signedNumber)
    }
    
    func testTypeName() throws {
        try check(sqlFile: "ParseTypeName", parser: { Parsers.typeName(state: &$0) })
    }
    
    func testCreateTable() throws {
        try check(sqlFile: "ParseCreateTable", parser: Parsers.createTableStmt)
    }
    
    func testBindParameter() throws {
        try check(sqlFile: "ParseBindParameter", parser: Parsers.bindParameter, dump: true)
    }
    
    func testOpertators() throws {
        try check(sqlFile: "ParseOperators", parser: Parsers.operator)
    }
    
    func testExpression() throws {
        try check(sqlFile: "ParseExpression", parser: { try Parsers.expr(state: &$0) })
    }
    
    func testSelectStmt() throws {
        try check(sqlFile: "ParseSelectStmt", parser: Parsers.selectStmt)
    }
    
    func testJoinConstraint() throws {
        try check(sqlFile: "ParseJoinConstraint", parser: Parsers.joinConstraint)
    }
    
    func testCommonTableExpression() throws {
        try check(sqlFile: "ParseCommonTableExpression", parser: Parsers.cte)
    }
    
    func testJoinOperator() throws {
        try check(sqlFile: "ParseJoinOperator", parser: Parsers.joinOperator)
    }
    
    func testOrderingTerm() throws {
        try check(sqlFile: "ParseOrderingTerm", parser: Parsers.orderingTerm)
    }
    
    func testResultColumn() throws {
        try check(sqlFile: "ParseResultColumn", parser: Parsers.resultColumn)
    }
    
    func testTableOrSubquery() throws {
        try check(sqlFile: "ParseTableOrSubquery", parser: Parsers.tableOrSubquery)
    }
    
    func testJoinClause() throws {
        try check(sqlFile: "ParseJoinClause", parser: Parsers.joinClauseOrTableOrSubqueries)
    }
    
    func testInsertStmt() throws {
        try check(sqlFile: "ParseInsertStmt", parser: Parsers.insertStmt)
    }
    
    func testUpdateStmt() throws {
        try check(sqlFile: "ParseUpdateStmt", parser: Parsers.updateStmt)
    }
    
    func testDefinition() throws {
        try check(sqlFile: "ParseDefinition", parser: Parsers.definition)
    }
    
    func testTableConstraints() throws {
        try check(sqlFile: "ParseTableConstraint", parser: Parsers.tableConstraint)
    }
    
    func testDeleteStmt() throws {
        try check(sqlFile: "ParseDeleteStmt", parser: Parsers.deleteStmt)
    }
    
    func testPragmas() throws {
        try check(sqlFile: "ParsePragma", parser: Parsers.pragma)
    }
    
    func testDropTable() throws {
        try check(sqlFile: "ParseDropTableStmt", parser: Parsers.dropTable)
    }
    
    func testCreateIndex() throws {
        try check(sqlFile: "ParseCreateIndexStmt", parser: Parsers.createIndex)
    }
    
    func testDropIndex() throws {
        try check(sqlFile: "ParseDropIndexStmt", parser: Parsers.dropIndex)
    }
    
    func testReindex() throws {
        try check(sqlFile: "ParseReindexStmt", parser: Parsers.reindex)
    }
    
    func testCreateView() throws {
        try check(sqlFile: "ParseCreateViewStmt", parser: Parsers.createView)
    }
    
    func testDropView() throws {
        try check(sqlFile: "ParseDropViewStmt", parser: Parsers.dropView)
    }
    
    func testCreateVirtualTable() throws {
        try check(sqlFile: "ParseCreateVirtualTable", parser: Parsers.createVirutalTable)
    }
    
    func testCreateTrigger() throws {
        try check(sqlFile: "ParseCreateTriggerStmt", parser: Parsers.createTrigger)
    }
    
    func testDropTrigger() throws {
        try check(sqlFile: "ParseDropTriggerStmt", parser: Parsers.dropTrigger) 
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

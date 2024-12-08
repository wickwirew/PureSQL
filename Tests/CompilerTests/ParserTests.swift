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
        try check(sqlFile: "TableOptions", parse: Parsers.tableOptions)
    }
    
    func testConflictClause() throws {
        try check(sqlFile: "ConflictClause", parse: Parsers.conflictClause)
    }
    
    func testForeignKeyClause() throws {
        try check(sqlFile: "ForeignKeyClause", parse: Parsers.foreignKeyClause)
    }
    
    func testOrder() throws {
        try check(sqlFile: "Order", parse: Parsers.order)
    }
    
    func testColumnConstraint() throws {
        try check(sqlFile: "ColumnConstraint", parse: { Parsers.columnConstraint(state: &$0) })
    }
    
    func testColumnDefinition() throws {
        try check(sqlFile: "ColumnDefinition", parse: Parsers.columnDef)
    }
    
    func testAlterTable() throws {
        try check(sqlFile: "AlterTable", parse: Parsers.alterStmt)
    }
    
    func testSignedNumber() throws {
        try check(sqlFile: "SignedNumber", parse: Parsers.signedNumber)
    }
    
    func testTypeName() throws {
        try check(sqlFile: "TypeName", parse: Parsers.typeName)
    }
    
    func testCreateTable() throws {
        try check(sqlFile: "CreateTable", parse: Parsers.createTableStmt)
    }
    
    func testBindParameter() throws {
        try check(sqlFile: "BindParameter", parse: Parsers.bindParameter)
    }
    
    func testOpertators() throws {
        try check(sqlFile: "Operators", parse: Parsers.operator)
    }
    
    func testExpression() throws {
        try check(sqlFile: "Expression", parse: { Parsers.expr(state: &$0) })
    }
    
    func testSelectStmt() throws {
        try check(sqlFile: "SelectStmt", parse: Parsers.selectStmt)
    }
    
    func testJoinConstraint() throws {
        try check(sqlFile: "JoinConstraint", parse: Parsers.joinConstraint)
    }
    
    func testCommonTableExpression() throws {
        try check(sqlFile: "CommonTableExpression", parse: Parsers.cte)
    }
    
    func testJoinOperator() throws {
        try check(sqlFile: "JoinOperator", parse: Parsers.joinOperator)
    }
    
    func testOrderingTerm() throws {
        try check(sqlFile: "OrderingTerm", parse: Parsers.orderingTerm)
    }
    
    func testResultColumn() throws {
        try check(sqlFile: "ResultColumn", parse: Parsers.resultColumn)
    }
    
    func testTableOrSubquery() throws {
        try check(sqlFile: "TableOrSubquery", parse: Parsers.tableOrSubquery)
    }
    
    func testJoinClause() throws {
        try check(sqlFile: "JoinClause", parse: Parsers.joinClauseOrTableOrSubqueries)
    }
    
    func testInsertStmt() throws {
        try check(sqlFile: "InsertStmt", parse: Parsers.insertStmt)
    }
    
    func testUpdateStmt() throws {
        try check(sqlFile: "UpdateStmt", parse: Parsers.updateStmt)
    }
}

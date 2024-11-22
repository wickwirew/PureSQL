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
        try check(sqlFile: "TableOptions", parser: TableOptionsParser())
    }
    
    func testConflictClause() throws {
        try check(sqlFile: "ConflictClause", parser: ConfictClauseParser())
    }
    
    func testForeignKeyClause() throws {
        try check(sqlFile: "ForeignKeyClause", parser: ForeignKeyClauseParser())
    }
    
    func testOrder() throws {
        try check(sqlFile: "Order", parser: OrderParser())
    }
    
    func testColumnConstraint() throws {
        try check(sqlFile: "ColumnConstraint", parser: ColumnConstraintParser())
    }
    
    func testColumnDefinition() throws {
        try check(sqlFile: "ColumnDefinition", parser: ColumnDefinitionParser())
    }
    
    func testAlterTable() throws {
        try check(sqlFile: "AlterTable", parser: AlterTableParser())
    }
    
    func testSignedNumber() throws {
        try check(sqlFile: "SignedNumber", parser: SignedNumberParser())
    }
    
    func testTypeName() throws {
        try check(sqlFile: "TypeName", parser: TypeNameParser())
    }
    
    func testCreateTable() throws {
        try check(sqlFile: "CreateTable", parser: CreateTableParser())
    }
    
    func testBindParameter() throws {
        try check(sqlFile: "BindParameter", parser: BindParameterParser())
    }
    
    func testOpertators() throws {
        try check(sqlFile: "Operators", parser: OperatorParser())
    }
    
    func testExpression() throws {
        try check(sqlFile: "Expression", parser: ExprParser())
    }
    
    func testSelectStmt() throws {
        try check(sqlFile: "SelectStmt", parser: SelectStmtParser())
    }
    
    func testJoinConstraint() throws {
        try check(sqlFile: "JoinConstraint", parser: JoinConstraintParser())
    }
    
    func testCommonTableExpression() throws {
        try check(sqlFile: "CommonTableExpression", parser: CommonTableExprParser())
    }
    
    func testJoinOperator() throws {
        try check(sqlFile: "JoinOperator", parser: JoinOperatorParser())
    }
    
    func testOrderingTerm() throws {
        try check(sqlFile: "OrderingTerm", parser: OrderingTermParser())
    }
    
    func testResultColumn() throws {
        try check(sqlFile: "ResultColumn", parser: ResultColumnParser())
    }
    
    func testTableOrSubquery() throws {
        try check(sqlFile: "TableOrSubquery", parser: TableOrSubqueryParser())
    }
    
    func testJoinClause() throws {
        try check(sqlFile: "JoinClause", parser: JoinClauseOrTableOrSubqueryParser())
    }
}

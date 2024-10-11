//
//  ParserTests.swift
//  
//
//  Created by Wes Wickwire on 10/9/24.
//

import XCTest
import Schema

@testable import Parser

/// Just tests for the smaller, less complex parsers that dont really need their own file.
final class ParserTests: XCTestCase {
    private func parserState(_ source: String) throws -> ParserState {
        return try ParserState(Lexer(source: source))
    }
    
    private func execute<P: Parser>(parser: P, source: String) throws -> P.Output {
        var state = try parserState(source)
        return try parser.parse(state: &state)
    }
}

// MARK: - TableOptions

extension ParserTests {
    func testTableOptionsEmpty() throws {
        let result = try execute(parser: TableOptionsParser(), source: "")
        
        XCTAssertEqual(result, [])
    }
    
    func testTableOptionsWithoutRowId() throws {
        let result = try execute(parser: TableOptionsParser(), source: "WITHOUT ROWID")
        XCTAssertEqual(result, [.withoutRowId])
    }
    
    func testTableOptionsStrict() throws {
        let result = try execute(parser: TableOptionsParser(), source: "STRICT")
        XCTAssertEqual(result, [.strict])
    }
    
    func testTableOptionsAll() throws {
        let result = try execute(parser: TableOptionsParser(), source: "WITHOUT ROWID, STRICT")
        XCTAssertEqual(result, [.strict, .withoutRowId])
    }
    
    func testTableOptionsDoesNoConsumeNextToken() throws {
        var state = try parserState("WITHOUT ROWID SELECT")
        let result = try TableOptionsParser().parse(state: &state)
        XCTAssertEqual(result, [.withoutRowId, .withoutRowId])
        XCTAssertEqual(.select, try state.take().kind)
    }
}

// MARK: - Ty

extension ParserTests {
    func testAllTypes() {
        XCTAssertEqual(.int, try execute(parser: TyParser(), source: "INT"))
        XCTAssertEqual(.integer, try execute(parser: TyParser(), source: "INTEGER"))
        XCTAssertEqual(.tinyint, try execute(parser: TyParser(), source: "TINYINT"))
        XCTAssertEqual(.smallint, try execute(parser: TyParser(), source: "SMALLINT"))
        XCTAssertEqual(.mediumint, try execute(parser: TyParser(), source: "MEDIUMINT"))
        XCTAssertEqual(.bigint, try execute(parser: TyParser(), source: "BIGINT"))
        XCTAssertEqual(.unsignedBigInt, try execute(parser: TyParser(), source: "UNSIGNED BIG INT"))
        XCTAssertEqual(.int2, try execute(parser: TyParser(), source: "INT2"))
        XCTAssertEqual(.int8, try execute(parser: TyParser(), source: "INT8"))
        XCTAssertEqual(.numeric, try execute(parser: TyParser(), source: "NUMERIC"))
        XCTAssertEqual(.boolean, try execute(parser: TyParser(), source: "BOOLEAN"))
        XCTAssertEqual(.date, try execute(parser: TyParser(), source: "DATE"))
        XCTAssertEqual(.datetime, try execute(parser: TyParser(), source: "DATETIME"))
        XCTAssertEqual(.real, try execute(parser: TyParser(), source: "REAL"))
        XCTAssertEqual(.double, try execute(parser: TyParser(), source: "DOUBLE"))
        XCTAssertEqual(.doublePrecision, try execute(parser: TyParser(), source: "DOUBLE PRECISION"))
        XCTAssertEqual(.float, try execute(parser: TyParser(), source: "FLOAT"))
        XCTAssertEqual(.text, try execute(parser: TyParser(), source: "TEXT"))
        XCTAssertEqual(.clob, try execute(parser: TyParser(), source: "CLOB"))
        XCTAssertEqual(.blob, try execute(parser: TyParser(), source: "BLOB"))
        XCTAssertEqual(.decimal(1, 2), try execute(parser: TyParser(), source: "DECIMAL(1, 2)"))
        XCTAssertEqual(.character(1), try execute(parser: TyParser(), source: "CHARACTER(1)"))
        XCTAssertEqual(.varchar(1), try execute(parser: TyParser(), source: "VARCHAR(1)"))
        XCTAssertEqual(.varyingCharacter(1), try execute(parser: TyParser(), source: "VARYING CHARACTER(1)"))
        XCTAssertEqual(.nchar(1), try execute(parser: TyParser(), source: "NCHAR(1)"))
        XCTAssertEqual(.nvarchar(1), try execute(parser: TyParser(), source: "NVARCHAR(1)"))
        XCTAssertEqual(.nativeCharacter(1), try execute(parser: TyParser(), source: "NATIVE CHARACTER(1)"))
    }
    
    func testErrorIsThrownOn3Args() {
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "DECIMAL(1, 2, 3)"))
    }
    
    func testErrorIsThrownOnIncorrectArgNumber() {
        // If it needs 1, it gets 2, and if it needs 2 it gets 1 to throw the error
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "DECIMAL(1)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "CHARACTER(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "VARCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "VARYING CHARACTER(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NVARCHAR(1, 2)"))
        XCTAssertThrowsError(try execute(parser: TyParser(), source: "NATIVE CHARACTER(1, 2)"))
    }
}

// MARK: - Symbol

extension ParserTests {
    func testSymbol() {
        XCTAssertEqual("userId", try execute(parser: SymbolParser(), source: "userId"))
    }
    
    func testKeyword() {
        XCTAssertThrowsError(try execute(parser: SymbolParser(), source: "SELECT"))
    }
}

// MARK: - SignedNumber

extension ParserTests {
    func testNoSign() {
        XCTAssertEqual(123, try execute(parser: SignedNumberParser(), source: "123"))
    }
    
    func testPositiveSign() {
        XCTAssertEqual(123, try execute(parser: SignedNumberParser(), source: "+123"))
    }
    
    func testNegativeSign() {
        XCTAssertEqual(-123, try execute(parser: SignedNumberParser(), source: "-123"))
    }
}

// MARK: - ConflictClause

extension ParserTests {
    func testConflictClauses() {
        XCTAssertEqual(.none, try execute(parser: ConfictClauseParser(), source: ""))
        XCTAssertEqual(.rollback, try execute(parser: ConfictClauseParser(), source: "ON CONFLICT ROLLBACK"))
        XCTAssertEqual(.abort, try execute(parser: ConfictClauseParser(), source: "ON CONFLICT ABORT"))
        XCTAssertEqual(.fail, try execute(parser: ConfictClauseParser(), source: "ON CONFLICT FAIL"))
        XCTAssertEqual(.ignore, try execute(parser: ConfictClauseParser(), source: "ON CONFLICT IGNORE"))
        XCTAssertEqual(.replace, try execute(parser: ConfictClauseParser(), source: "ON CONFLICT REPLACE"))
    }
    
    func testConflictClausesRequiresConflictKeyword() {
        XCTAssertThrowsError(try execute(parser: ConfictClauseParser(), source: "ON ROLLBACK"))
    }
    
    func testConflictClausesThrowsErrorWithNoAction() {
        XCTAssertThrowsError(try execute(parser: ConfictClauseParser(), source: "ON CONFLICT"))
    }
}

// MARK: - ForeignKeyClause

extension ParserTests {
    func testForeignKeyClauseSimpleReference() {
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: [], actions: []),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: []),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id)")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id", "foo"], actions: []),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id, foo)")
        )
    }
    
    func testForeignKeyOnDelete() {
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .setNull)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON DELETE SET NULL")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .setDefault)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON DELETE SET DEFAULT")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: [], actions: [.onDo(.delete, .cascade)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user ON DELETE CASCADE")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .restrict)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON DELETE RESTRICT")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .noAction)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON DELETE NO ACTION")
        )
    }
    
    func testForeignKeyOnUpdate() {
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.update, .setNull)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON UPDATE SET NULL")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.update, .setDefault)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON UPDATE SET DEFAULT")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: [], actions: [.onDo(.update, .cascade)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user ON UPDATE CASCADE")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.update, .restrict)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON UPDATE RESTRICT")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.update, .noAction)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) ON UPDATE NO ACTION")
        )
    }
    
    func testForeignKeyClauseMatch() {
        XCTAssertEqual(
            ForeignKeyClause(
                foreignTable: "user",
                foreignColumns: ["id"],
                actions: [.match(
                    "SIMPLE",
                    [.onDo(.delete, .cascade), .onDo(.update, .noAction)]
                )]
            ),
            try execute(
                parser: ForeignKeyClauseParser(),
                source: "REFERENCES user(id) MATCH SIMPLE ON DELETE CASCADE ON UPDATE NO ACTION"
            )
        )
    }
    
    func testForeignKeyClauseDeferrable() {
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.notDeferrable(nil)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) NOT DEFERRABLE")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.notDeferrable(.initiallyDeferred)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) NOT DEFERRABLE INITIALLY DEFERRED")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.notDeferrable(.initiallyImmediate)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) NOT DEFERRABLE INITIALLY IMMEDIATE")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.deferrable(nil)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) DEFERRABLE")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.deferrable(.initiallyDeferred)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) DEFERRABLE INITIALLY DEFERRED")
        )
        
        XCTAssertEqual(
            ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.deferrable(.initiallyImmediate)]),
            try execute(parser: ForeignKeyClauseParser(), source: "REFERENCES user(id) DEFERRABLE INITIALLY IMMEDIATE")
        )
    }
}

// MARK: - Order

extension ParserTests {
    func testOrder() {
        XCTAssertEqual(.asc, try execute(parser: OrderParser(), source: "ASC"))
        XCTAssertEqual(.desc, try execute(parser: OrderParser(), source: "DESC"))
        XCTAssertEqual(.asc, try execute(parser: OrderParser(), source: ""))
    }
    
    func testOrderDoesNotConsumePastIfNoValue() throws {
        var state = try parserState("SELECT")
        XCTAssertEqual(.asc, try OrderParser().parse(state: &state))
        XCTAssertEqual(.select, try state.take().kind)
    }
}

// MARK: - ColumnConstraint

extension ParserTests {
    func testColumnConstraintPk() {
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .primaryKey(order: .asc, .none, autoincrement: false)),
            try execute(parser: ColumnConstraintParser(), source: "PRIMARY KEY")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .primaryKey(order: .desc, .none, autoincrement: true)),
            try execute(parser: ColumnConstraintParser(), source: "PRIMARY KEY DESC AUTOINCREMENT")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .primaryKey(order: .desc, .fail, autoincrement: true)),
            try execute(parser: ColumnConstraintParser(), source: "PRIMARY KEY DESC ON CONFLICT FAIL AUTOINCREMENT")
        )
    }
    
    func testColumnConstraintFk() {
        XCTAssertEqual(
            ColumnConstraint(
                name: "toUser",
                kind: .foreignKey(
                    ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .cascade)])
                )
            ),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT toUser REFERENCES user(id) ON DELETE CASCADE")
        )
        
        XCTAssertEqual(
            ColumnConstraint(
                name: nil,
                kind: .foreignKey(
                    ForeignKeyClause(foreignTable: "user", foreignColumns: ["id"], actions: [.onDo(.delete, .cascade)])
                )
            ),
            try execute(parser: ColumnConstraintParser(), source: "REFERENCES user(id) ON DELETE CASCADE")
        )
    }
    
    func testColumnConstraintNotNull() {
        XCTAssertEqual(
            ColumnConstraint(name: "isNotNull", kind: .notNull(.none)),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT isNotNull NOT NULL")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .notNull(.fail)),
            try execute(parser: ColumnConstraintParser(), source: "NOT NULL ON CONFLICT FAIL")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .notNull(.none)),
            try execute(parser: ColumnConstraintParser(), source: "NOT NULL")
        )
    }
    
    func testColumnConstraintUnique() {
        XCTAssertEqual(
            ColumnConstraint(name: "isUnique", kind: .unique(.none)),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT isUnique UNIQUE")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .unique(.rollback)),
            try execute(parser: ColumnConstraintParser(), source: "UNIQUE ON CONFLICT rollback")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .unique(.none)),
            try execute(parser: ColumnConstraintParser(), source: "UNIQUE")
        )
    }
    
    func testColumnConstraintCheck() {
        // TODO: These will fail once expr parsing is implemented
        
        XCTAssertEqual(
            ColumnConstraint(name: "checkSomething", kind: .check(Expr())),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT checkSomething CHECK()")
        )

        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .check(Expr())),
            try execute(parser: ColumnConstraintParser(), source: "CHECK()")
        )
    }
    
    func testColumnConstraintDefault() {
        // TODO: These will fail once expr parsing is implemented
        
        XCTAssertEqual(
            ColumnConstraint(name: "setDefault", kind: .default(.literal(.numeric(1)))),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT setDefault DEFAULT 1")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .default(.expr(Expr()))),
            try execute(parser: ColumnConstraintParser(), source: "DEFAULT ()")
        )
    }
    
    func testColumnConstraintCollate() {
        XCTAssertEqual(
            ColumnConstraint(name: "hasCollate", kind: .collate("SIMPLE")),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT hasCollate COLLATE SIMPLE")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .collate("SIMPLE")),
            try execute(parser: ColumnConstraintParser(), source: "COLLATE SIMPLE")
        )
    }
    
    func testColumnConstraintGenerated() {
        XCTAssertEqual(
            ColumnConstraint(name: "generateTheColumn", kind: .generated(Expr(), .virtual)),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT generateTheColumn GENERATED ALWAYS AS () VIRTUAL")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .generated(Expr(), .stored)),
            try execute(parser: ColumnConstraintParser(), source: "GENERATED ALWAYS AS () STORED")
        )
    }
}

// MARK: - Column Definition

extension ParserTests {
    func testColumnDefinition() {
        XCTAssertEqual(
            ColumnDef(name: "age", type: .int, constraints: []),
            try execute(parser: ColumnDefinitionParser(), source: "age INT")
        )
        
        XCTAssertEqual(
            ColumnDef(name: "age", type: .bigint, constraints: []),
            try execute(parser: ColumnDefinitionParser(), source: "age BIGINT")
        )
        
        XCTAssertEqual(
            ColumnDef(name: "age", type: .unsignedBigInt, constraints: [ColumnConstraint(name: nil, kind: .notNull(.none))]),
            try execute(parser: ColumnDefinitionParser(), source: "age UNSIGNED BIG INT NOT NULL")
        )
    }
}

// MARK: - Alter Table

extension ParserTests {
    func testAlterTableRename() {
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .rename("coolUser")),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user RENAME TO coolUser")
        )
    }
    
    func testAlterTableRenameColumn() {
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .renameColumn("firstN", "firstName")),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user RENAME COLUMN firstN TO firstName")
        )
        
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .renameColumn("firstN", "firstName")),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user RENAME firstN TO firstName")
        )
    }
    
    func testAlterTableAddColumn() {
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .addColumn(ColumnDef(name: "lastName", type: .text, constraints: []))),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user ADD COLUMN lastName TEXT")
        )
        
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .addColumn(ColumnDef(name: "lastName", type: .text, constraints: []))),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user ADD lastName TEXT")
        )
    }
    
    func testAlterTableDropColumn() {
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .dropColumn("age")),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user DROP COLUMN age")
        )
        
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .dropColumn("age")),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user DROP age")
        )
    }
}

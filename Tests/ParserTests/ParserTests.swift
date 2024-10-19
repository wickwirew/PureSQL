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
        XCTAssertEqual(TypeName(name: "INT", args: nil), try execute(parser: TypeNameParser(), source: "INT"))
        XCTAssertEqual(TypeName(name: "INTEGER", args: nil), try execute(parser: TypeNameParser(), source: "INTEGER"))
        XCTAssertEqual(TypeName(name: "TINYINT", args: nil), try execute(parser: TypeNameParser(), source: "TINYINT"))
        XCTAssertEqual(TypeName(name: "SMALLINT", args: nil), try execute(parser: TypeNameParser(), source: "SMALLINT"))
        XCTAssertEqual(TypeName(name: "MEDIUMINT", args: nil), try execute(parser: TypeNameParser(), source: "MEDIUMINT"))
        XCTAssertEqual(TypeName(name: "BIGINT", args: nil), try execute(parser: TypeNameParser(), source: "BIGINT"))
        XCTAssertEqual(TypeName(name: "UNSIGNED BIG INT", args: nil), try execute(parser: TypeNameParser(), source: "UNSIGNED BIG INT"))
        XCTAssertEqual(TypeName(name: "INT2", args: nil), try execute(parser: TypeNameParser(), source: "INT2"))
        XCTAssertEqual(TypeName(name: "INT8", args: nil), try execute(parser: TypeNameParser(), source: "INT8"))
        XCTAssertEqual(TypeName(name: "NUMERIC", args: nil), try execute(parser: TypeNameParser(), source: "NUMERIC"))
        XCTAssertEqual(TypeName(name: "BOOLEAN", args: nil), try execute(parser: TypeNameParser(), source: "BOOLEAN"))
        XCTAssertEqual(TypeName(name: "DATE", args: nil), try execute(parser: TypeNameParser(), source: "DATE"))
        XCTAssertEqual(TypeName(name: "DATETIME", args: nil), try execute(parser: TypeNameParser(), source: "DATETIME"))
        XCTAssertEqual(TypeName(name: "REAL", args: nil), try execute(parser: TypeNameParser(), source: "REAL"))
        XCTAssertEqual(TypeName(name: "DOUBLE", args: nil), try execute(parser: TypeNameParser(), source: "DOUBLE"))
        XCTAssertEqual(TypeName(name: "DOUBLE PRECISION", args: nil), try execute(parser: TypeNameParser(), source: "DOUBLE PRECISION"))
        XCTAssertEqual(TypeName(name: "FLOAT", args: nil), try execute(parser: TypeNameParser(), source: "FLOAT"))
        XCTAssertEqual(TypeName(name: "TEXT", args: nil), try execute(parser: TypeNameParser(), source: "TEXT"))
        XCTAssertEqual(TypeName(name: "CLOB", args: nil), try execute(parser: TypeNameParser(), source: "CLOB"))
        XCTAssertEqual(TypeName(name: "BLOB", args: nil), try execute(parser: TypeNameParser(), source: "BLOB"))
        XCTAssertEqual(TypeName(name: "DECIMAL", args: .two(1, 2)), try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2)"))
        XCTAssertEqual(TypeName(name: "CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "CHARACTER(1)"))
        XCTAssertEqual(TypeName(name: "VARCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "VARCHAR(1)"))
        XCTAssertEqual(TypeName(name: "VARYING CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "VARYING CHARACTER(1)"))
        XCTAssertEqual(TypeName(name: "NCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "NCHAR(1)"))
        XCTAssertEqual(TypeName(name: "NVARCHAR", args: .one(1)), try execute(parser: TypeNameParser(), source: "NVARCHAR(1)"))
        XCTAssertEqual(TypeName(name: "NATIVE CHARACTER", args: .one(1)), try execute(parser: TypeNameParser(), source: "NATIVE CHARACTER(1)"))
    }
    
    func testErrorIsThrownOn3Args() {
        XCTAssertThrowsError(try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2, 3)"))
    }
    
    func testErrorIsThrownOnIncorrectArgNumber() {
        XCTAssertThrowsError(try execute(parser: TypeNameParser(), source: "DECIMAL(1, 2, 3)"))
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
            ColumnConstraint(name: "checkSomething", kind: .check(.bindParameter(.unnamed))),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT checkSomething CHECK(?)")
        )

        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .check(.bindParameter(.unnamed))),
            try execute(parser: ColumnConstraintParser(), source: "CHECK(?)")
        )
    }
    
    func testColumnConstraintDefault() {
        // TODO: These will fail once expr parsing is implemented
        
        XCTAssertEqual(
            ColumnConstraint(name: "setDefault", kind: .default(.literal(.numeric(1, isInt: true)))),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT setDefault DEFAULT 1")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .default(.expr(.bindParameter(.unnamed)))),
            try execute(parser: ColumnConstraintParser(), source: "DEFAULT (?)")
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
            ColumnConstraint(name: "generateTheColumn", kind: .generated(.bindParameter(.unnamed), .virtual)),
            try execute(parser: ColumnConstraintParser(), source: "CONSTRAINT generateTheColumn GENERATED ALWAYS AS (?) VIRTUAL")
        )
        
        XCTAssertEqual(
            ColumnConstraint(name: nil, kind: .generated(.bindParameter(.unnamed), .stored)),
            try execute(parser: ColumnConstraintParser(), source: "GENERATED ALWAYS AS (?) STORED")
        )
    }
}

// MARK: - Column Definition

extension ParserTests {
    func testColumnDefinition() {
        XCTAssertEqual(
            ColumnDef(name: "age", type: TypeName(name: "INT", args: nil), constraints: []),
            try execute(parser: ColumnDefinitionParser(), source: "age INT")
        )
        
        XCTAssertEqual(
            ColumnDef(name: "age", type: TypeName(name: "BIGINT", args: nil), constraints: []),
            try execute(parser: ColumnDefinitionParser(), source: "age BIGINT")
        )
        
        XCTAssertEqual(
            ColumnDef(name: "age", type: TypeName(name: "UNSIGNED BIG INT", args: nil), constraints: [ColumnConstraint(name: nil, kind: .notNull(.none))]),
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
            AlterTableStatement(name: "user", schemaName: nil, kind: .addColumn(ColumnDef(name: "lastName", type: TypeName(name: "TEXT", args: nil), constraints: []))),
            try execute(parser: AlterTableParser(), source: "ALTER TABLE user ADD COLUMN lastName TEXT")
        )
        
        XCTAssertEqual(
            AlterTableStatement(name: "user", schemaName: nil, kind: .addColumn(ColumnDef(name: "lastName", type: TypeName(name: "TEXT", args: nil), constraints: []))),
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

extension ParserTests {
    func testMultipleStatements() throws {
        let result = try! execute(
            parser: StmtParser()
                .semiColonSeparated(),
            source: """
            CREATE TABLE user (
                id INT PRIMARY KEY AUTOINCREMENT,
                firstName TEXT,
                lastName TEXT,
                age INT NOT NULL
            );
            
            ALTER TABLE user ADD COLUMN favoriteColor TEXT;
            """
        )
        
        print(result)
    }
}

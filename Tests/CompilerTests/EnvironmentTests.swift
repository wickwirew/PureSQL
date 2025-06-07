//
//  EnvironmentTests.swift
//  Feather
//
//  Created by Wes Wickwire on 6/1/25.
//

import Testing
@testable import Compiler

@Suite
struct EnvironmentTests {
    @Test func columnsCanBeResolvedViaShortAndQualifiedNames() async throws {
        let table = table(name: "foo")
        var env = Environment()
        env.import(table: table, isOptional: false)
        
        #expect(.success(.integer) == env.resolve(column: "bar", table: nil, schema: nil))
        #expect(.success(.integer) == env.resolve(column: "bar", table: "foo", schema: nil))
        #expect(.success(.integer) == env.resolve(column: "bar", table: "foo", schema: "main"))
    }
    
    @Test func columnWithDuplicateNameIsAmbiguous() async throws {
        let table1 = table(name: "one")
        let table2 = table(name: "two")
        
        var env = Environment()
        env.import(table: table1, isOptional: false)
        env.import(table: table2, isOptional: false)
        
        #expect(.ambiguous(.text) == env.resolve(column: "baz", table: nil, schema: nil))
    }
    
    @Test func columnWithDuplicateNameCanBeNotAmbigousIfQualified() async throws {
        let table1 = table(name: "one")
        let table2 = table(name: "two")
        
        var env = Environment()
        env.import(table: table1, isOptional: false)
        env.import(table: table2, isOptional: false)
        
        #expect(.success(.integer) == env.resolve(column: "bar", table: "one", schema: nil))
        #expect(.success(.integer) == env.resolve(column: "bar", table: "two", schema: nil))
    }
    
    @Test func tableWithNoSchemaCanBeResolved() async throws {
        let table = table(name: "cte", schema: nil)
        var env = Environment()
        env.import(table: table, isOptional: false)
        
        #expect(table == env.resolve(table: "cte", schema: nil).value)
        #expect(.success(.integer) == env.resolve(column: "bar", table: "cte", schema: nil))
        #expect(.tableDoesNotExist("cte") == env.resolve(table: "cte", schema: "main"))
    }
    
    @Test func ftsTableHasRankInserted() async throws {
        let table = table(name: "fts", kind: .fts5)
        var env = Environment()
        env.import(table: table, isOptional: false)
        
        #expect(table == env.resolve(table: "fts", schema: nil).value)
        #expect(.success(.real) == env.resolve(column: "rank", table: "fts", schema: nil))
        #expect(.success(.real) == env.resolve(column: "rank", table: nil, schema: nil))
    }
    
    @Test func tableImportedOptionallyHasOptionalColumns() async throws {
        let table = table(name: "foo")
        var env = Environment()
        env.import(table: table, isOptional: true)
        
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: nil, schema: nil))
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: "foo", schema: nil))
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: "foo", schema: "main"))
    }
    
    @Test func optionalColumnsAreNotCoercedToDoubleOptional() async throws {
        let table = table(name: "foo", columns: ["bar": .optional(.integer)])
        var env = Environment()
        env.import(table: table, isOptional: true)
        
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: nil, schema: nil))
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: "foo", schema: nil))
        #expect(.success(.optional(.integer)) == env.resolve(column: "bar", table: "foo", schema: "main"))
    }
    
    @Test func nonLocalsAddedWithEmptyEnvironmentDoesNotCrash() {
        let env = Environment()
        let diff = env.nonLocalsAdded(in: Environment())
        #expect(diff.tables.isEmpty)
        #expect(diff.values.isEmpty)
    }
    
    @Test func nonLocalsAddedReturnsNewlyInsertedTable() {
        let env = Environment()
        let table = table(name: "foo")
        var newEnv = Environment()
        newEnv.import(table: table, isOptional: false)
        let diff = env.nonLocalsAdded(in: newEnv)
        #expect(diff.tables[0].value.table == table)
    }
    
    @Test func originalTableIsNotReturnedWhenAliased() {
        var env = Environment()
        let table = table(name: "foo")
        
        var newEnv = Environment()
        newEnv.import(table: table, alias: "bar", isOptional: false)
        
        env.importNonLocals(in: newEnv)
        
        #expect(env.resolve(table: "bar", schema: nil).value == table)
        #expect(env.resolve(table: "bar", schema: "main").value == nil)
    }
    
    private func table(
        name: Substring,
        schema: SchemaName? = .main,
        columns: Columns = ["foo": .text, "bar": .integer, "baz": .text],
        kind: Table.Kind = .normal
    ) -> Table {
        return Table(
            name: QualifiedName(name: name, schema: schema),
            columns: columns,
            primaryKey: [],
            kind: kind
        )
    }
}

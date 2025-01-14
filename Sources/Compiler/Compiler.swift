//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

import OrderedCollections

public struct CompiledTable {
    public var name: Substring
    public var columns: OrderedDictionary<Substring, Type>
    
    var type: Type {
        return .row(.named(columns))
    }
}

public enum CompiledStmt {
    case query(Signature)
    case table(CompiledTable)
}

public struct Signature: CustomReflectable {
    public var parameters: [Int: Parameter]
    public var output: Type?
    
    public var customMirror: Mirror {
        let outputTypes: [String] = if case let .row(.named(columns)) = output {
            columns.elements.map { "\($0) \($1)" }
        } else {
            []
        }
        
        return Mirror(
            self,
            children: [
                "parameters": parameters.values
                    .map(\.self)
                    .sorted(by: { $0.index < $1.index }),
                "output": outputTypes,
            ]
        )
    }
}

public struct Parameter {
    public let type: Type
    public let index: Int
    public let name: Substring?
}

struct Compiler {
    private(set) var schema: Schema
    private(set) var diagnostics = Diagnostics()
    private(set) var queries: [Signature] = []
    
    public init(
        schema: Schema = Schema(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    mutating func compile(_ stmts: [Stmt]) {
        for stmt in stmts {
            switch stmt.accept(visitor: &self) {
            case let .table(table):
                schema[table.name] = table
            case let .query(query):
                queries.append(query)
            case nil:
                break
            }
        }
    }
    
    mutating func compile(_ source: String) {
        compile(Parsers.parse(source: source))
    }
}

extension Compiler: StmtVisitor {
    mutating func visit(_ stmt: borrowing CreateTableStmt) -> CompiledStmt? {
        switch stmt.kind {
        case let .select(selectStmt):
            let signature = compile(select: selectStmt)
            guard case let .row(.named(columns)) = signature.output else { return nil }
            return .table(CompiledTable(name: stmt.name.value, columns: columns))
        case let .columns(columns):
            return .table(CompiledTable(
                name: stmt.name.value,
                columns: columns.reduce(into: [:]) { $0[$1.value.name.value] = typeFor(column: $1.value) }
            ))
        }
    }
    
    mutating func visit(_ stmt: borrowing AlterTableStmt) -> CompiledStmt? {
        guard var table = schema[stmt.name.value] else {
            diagnostics.add(.init("Table '\(stmt.name)' does not exist", at: stmt.name.range))
            return nil
        }
        
        switch stmt.kind {
        case let .rename(newName):
            schema[stmt.name.value] = nil
            schema[newName.value] = table
        case let .renameColumn(oldName, newName):
            table.columns = table.columns.reduce(into: [:]) { $0[$1.key == oldName.value ? newName.value : $1.key] = $1.value }
        case let .addColumn(column):
            table.columns[column.name.value] = typeFor(column: column)
        case let .dropColumn(column):
            table.columns[column.value] = nil
        }
        
        return .table(table)
    }
    
    mutating func visit(_ stmt: borrowing SelectStmt) -> CompiledStmt? {
        return .query(compile(select: stmt))
    }
    
    mutating func visit(_ stmt: borrowing InsertStmt) -> CompiledStmt? {
        var queryCompiler = TypeInferrer(env: Environment(), schema: schema)
        let solution = queryCompiler.solution(for: stmt)
        diagnostics.add(contentsOf: solution.diagnostics)
        return .query(solution.signature)
    }
    
    mutating func visit(_ stmt: borrowing EmptyStmt) -> CompiledStmt? {
        return nil
    }
    
    private func typeFor(column: borrowing ColumnDef) -> Type {
        // Technically you can have a NULL primary key but I don't
        // think people actually do that...
        let isNotNullable = column.constraints
            .contains { $0.isPkConstraint || $0.isNotNullConstraint }
        
        if isNotNullable {
            return .nominal(column.type.name.value)
        } else {
            return .optional(.nominal(column.type.name.value))
        }
    }
    
    private mutating func compile(select: borrowing SelectStmt) -> Signature {
        var queryCompiler = TypeInferrer(env: Environment(), schema: schema)
        let solution = queryCompiler.solution(for: select)
        diagnostics.add(contentsOf: solution.diagnostics)
        return solution.signature
    }
}

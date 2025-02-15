//
//  Compiler.swift
//
//
//  Created by Wes Wickwire on 11/1/24.
//

struct Compiler {
    private(set) var schema: Schema
    private(set) var diagnostics = Diagnostics()
    private(set) var statements: [Statement] = []
    
    public init(
        schema: Schema = Schema(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    mutating func compile(_ stmts: [StmtSyntax]) {
        for stmt in stmts {
            statements.append(stmt.accept(visitor: &self))
        }
    }
    
    mutating func compile(_ source: String) {
        compile(Parsers.parse(source: source))
    }
}

extension Compiler: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) -> Statement {
        switch stmt.kind {
        case let .select(selectStmt):
            let signature = compile(select: selectStmt)
            
            guard case let .row(.named(columns)) = signature.output else {
                assertionFailure("Create table did not have named columns")
                return Statement(name: nil, signature: .empty, syntax: stmt)
            }
            
            schema[stmt.name.value] = Table(name: stmt.name.value, columns: columns)
            return Statement(name: nil, signature: signature, syntax: stmt)
        case let .columns(columns):
            schema[stmt.name.value] = Table(
                name: stmt.name.value,
                columns: columns.reduce(into: [:]) { $0[$1.value.name.value] = typeFor(column: $1.value) }
            )
            return Statement(name: nil, signature: .empty, syntax: stmt)
        }
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) -> Statement {
        guard var table = schema[stmt.name.value] else {
            diagnostics.add(.init("Table '\(stmt.name)' does not exist", at: stmt.name.range))
            return Statement(name: nil, signature: .empty, syntax: stmt)
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
        
        schema[stmt.name.value] = table
        return Statement(name: nil, signature: .empty, syntax: stmt)
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) -> Statement {
        return Statement(name: nil, signature: compile(select: stmt), syntax: stmt)
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) -> Statement {
        var queryCompiler = TypeInferrer(env: Environment(), schema: schema)
        let solution = queryCompiler.solution(for: stmt)
        diagnostics.add(contentsOf: solution.diagnostics)
        return Statement(name: nil, signature: solution.signature, syntax: stmt)
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) -> Statement {
        let inner = stmt.statement.accept(visitor: &self)
        return Statement(name: stmt.name.value, signature: inner.signature, syntax: stmt)
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) -> Statement {
        return Statement(name: nil, signature: .empty, syntax: stmt)
    }
    
    private func typeFor(column: borrowing ColumnDefSyntax) -> Type {
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
    
    private mutating func compile(select: borrowing SelectStmtSyntax) -> Signature {
        var queryCompiler = TypeInferrer(env: Environment(), schema: schema)
        let solution = queryCompiler.solution(for: select)
        diagnostics.add(contentsOf: solution.diagnostics)
        return solution.signature
    }
}

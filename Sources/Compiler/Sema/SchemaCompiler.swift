//
//  SchemaCompiler.swift
//  Feather
//
//  Created by Wes Wickwire on 2/20/25.
//

import OrderedCollections

/// Manages compiling just the migrations that would affect the schema
public struct SchemaCompiler {
    public private(set) var schema: Schema
    private var diagnostics = Diagnostics()
    public private(set) var pragmas = PragmaAnalysis()
    
    public init(
        schema: Schema = Schema(),
        diagnostics: Diagnostics = Diagnostics()
    ) {
        self.schema = schema
        self.diagnostics = diagnostics
    }
    
    public var allDiagnostics: Diagnostics {
        return diagnostics.merging(pragmas.diagnostics)
    }
    
    public mutating func compile(_ source: String) -> String {
        var sanitizer = Sanitizer()
        
        for stmt in Parsers.parse(source: source) {
            stmt.accept(visitor: &self)
            sanitizer.combine(stmt)
        }
        
        return sanitizer.finalize(in: source)
    }
    
    /// Just performs type checking.
    private mutating func typeCheck<S: StmtSyntax>(_ stmt: S) {
        // Calculating the statement signature will type check it.
        // We can just ignore the output
        _ = signature(of: stmt)
    }
    
    /// Infers the signature of the stmt
    private mutating func signature<S: StmtSyntax>(of stmt: S) -> Signature {
        var inferrer = TypeChecker(schema: schema)
        let signature = inferrer.signature(for: stmt)
        self.diagnostics.merge(inferrer.diagnostics)
        return signature
    }
    
    /// Will figure out the final SQL column type from the syntax
    private func typeFor(column: borrowing ColumnDefSyntax) -> Type {
        // Technically you can have a NULL primary key but I don't
        // think people actually do that...
        let isNotNullable = column.constraints
            .contains { $0.isPkConstraint || $0.isNotNullConstraint }
        
        let nominal: Type = .nominal(column.type.name.value)
        
        let type: Type = if let alias = column.type.alias {
            .alias(nominal, alias.identifier.value)
        } else {
            nominal
        }
        
        if isNotNullable {
            return type
        } else {
            return .optional(type)
        }
    }
    
    /// Gets the column names of the primary key and validates them
    private mutating func primaryKey(
        of stmt: CreateTableStmtSyntax,
        columns: Columns
    ) -> [Substring] {
        // Any PK define by table constraints
        let byTableConstraints: [([IndexedColumnSyntax], TableConstraintSyntax)] = stmt.constraints
            .compactMap { constraint -> ([IndexedColumnSyntax], TableConstraintSyntax)? in
                guard case let .primaryKey(columns, _) = constraint.kind else { return nil }
                return (columns, constraint)
            }
        
        // Any PK defined at the column level
        let byColumnConstraints: [IdentifierSyntax]
        if case let .columns(columns) = stmt.kind {
            byColumnConstraints = columns.values
                .filter{ $0.constraints.contains(where: \.isPkConstraint) }
                .map(\.name)
        } else {
            // Due to parsing this should never be allowed to happen but easy to check
            if let constraint = byTableConstraints.first {
                diagnostics.add(.init(
                    "CREATE TABLE AS SELECT cannot have any constraints",
                    at: constraint.1.range
                ))
            }
            
            return []
        }
        
        // Make sure only 1 primary key constraint is added.
        // This allows for PRIMARY KEY(foo, bar) but not for multiple of those constraints
        if !byColumnConstraints.isEmpty, let constraint = byTableConstraints.first {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.range))
        } else if byColumnConstraints.count > 1, let constraint = byColumnConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.range))
        } else if byTableConstraints.count > 1, let constraint = byTableConstraints.last {
            diagnostics.add(.alreadyHasPrimaryKey(stmt.name.value, at: constraint.1.range))
        }
        
        if !byColumnConstraints.isEmpty && byTableConstraints.isEmpty {
            return byColumnConstraints.map(\.value)
        } else {
            // Make sure the columns actually exist since they are define afterwards
            var columnNames: [Substring] = []
            for constraint in byTableConstraints {
                for column in constraint.0 {
                    guard let name = column.columnName else { continue }
                    
                    if columns[name.value] == nil {
                        diagnostics.add(.columnDoesNotExist(name))
                    } else {
                        columnNames.append(name.value)
                    }
                }
            }
            return columnNames
        }
    }
}

extension SchemaCompiler: StmtSyntaxVisitor {
    mutating func visit(_ stmt: CreateTableStmtSyntax) {
        if pragmas.isOn(.requireStrictTables)
            && !stmt.options.contains(.strict) {
            diagnostics.add(.init(
                "Missing STRICT table option",
                at: stmt.range,
                suggestion: .append(" STRICT")
            ))
        }
        
        switch stmt.kind {
        case let .select(selectStmt):
            let signature = signature(of: selectStmt)
            
            guard case let .row(row) = signature.output else {
                fatalError("SELECT returned a non row type?")
            }
            
            let columns: Columns
            switch row {
            case .named(let c):
                columns = c
            case .unnamed(let types):
                // Technically this is allowed by SQLite, but the names are auto named `column1...`.
                // I don't think this is a good practice so might as well just error for now.
                // Can be accomplished by doing `CREATE TABLE foo AS VALUES (1, 2, 3);`
                diagnostics.add(.init("Result of SELECT did not have named columns", at: selectStmt.range))
                columns = types.enumerated().reduce(into: [:], { $0["column\($1.offset + 1)"] = $1.element })
            case .unknown(let type):
                // `unknown` is only used in inference, but might as well just set it
                columns = ["column1": type]
            }
            
            schema[stmt.name.value] = Table(
                name: stmt.name.value,
                columns: columns,
                primaryKey: primaryKey(of: stmt, columns: columns)
            )
        case let .columns(columns):
            let columns: Columns = columns.reduce(into: [:]) {
                $0[$1.value.name.value] = typeFor(column: $1.value)
            }
            
            schema[stmt.name.value] = Table(
                name: stmt.name.value,
                columns: columns,
                primaryKey: primaryKey(of: stmt, columns: columns)
            )
        }
    }
    
    mutating func visit(_ stmt: AlterTableStmtSyntax) {
        guard var table = schema[stmt.name.value] else {
            diagnostics.add(.init("Table '\(stmt.name)' does not exist", at: stmt.name.range))
            return
        }
        
        switch stmt.kind {
        case let .rename(newName):
            schema[stmt.name.value] = nil
            schema[newName.value] = table
        case let .renameColumn(oldName, newName):
            table.columns = table.columns.reduce(into: [:]) { newColumns, column in
                newColumns[column.key == oldName.value ? newName.value : column.key] = column.value
            }
        case let .addColumn(column):
            table.columns[column.name.value] = typeFor(column: column)
        case let .dropColumn(column):
            table.columns[column.value] = nil
        }
        
        schema[stmt.name.value] = table
    }
    
    mutating func visit(_ stmt: SelectStmtSyntax) {
        diagnostics.add(.illegalStatementInMigrations(.select, at: stmt.range))
    }
    
    mutating func visit(_ stmt: InsertStmtSyntax) {
        typeCheck(stmt)
    }
    
    mutating func visit(_ stmt: UpdateStmtSyntax) {
        typeCheck(stmt)
    }
    
    mutating func visit(_ stmt: DeleteStmtSyntax) {
        typeCheck(stmt)
    }
    
    mutating func visit(_ stmt: QueryDefinitionStmtSyntax) {
        diagnostics.add(.illegalStatementInMigrations(.define, at: stmt.range))
    }
    
    mutating func visit(_ stmt: PragmaStmt) {
        pragmas.handle(pragma: stmt)
    }
    
    mutating func visit(_ stmt: EmptyStmtSyntax) {}
}

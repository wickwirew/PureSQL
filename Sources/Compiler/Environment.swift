//
//  Environment.swift
//
//
//  Created by Wes Wickwire on 11/4/24.
//

/// The environment for which every query and statement is
/// type checked against as well as any other static analysis.
struct Environment {
    /// Any tables that are imported into the environment.
    private var importedTables: DuplicateDictionary<QualifiedName, ImportedTable> = [:]
    /// This is terribly named. I really can't think of a name for it other than this.
    /// When we import a table into the environment we can give it an alias `foo AS bar`
    /// which is nice. When that happens the original `foo` table is able to be access
    /// via the original name `foo.baz` and aliased name `bar.baz`. There is a unique caveat
    /// to this though. When building up the environment in a `FROM` any time there
    /// is a recursive table or sub query `(foo AS bar)` the tables that were imported from
    /// those resurive statements are only available under the aliased name, not the original.
    /// So the original tables become "locally imported" meaning they are really only
    /// valid to the local scope and should not be merged into a parent scope.
    private var locallyImportedTables: DuplicateDictionary<QualifiedName, ImportedTable> = [:]
    /// Detached values are all of the columns but detached from under their
    /// table. Also any defined column that is inserted without a table is
    /// in here as well. As well as the table themselves which allows
    /// them to be used in a `IN` and `MATCH` statements
    private var detachedValues: DuplicateDictionary<Substring, Type> = [:]
    
    @Indirect private var parent: Environment?

    /// A result type for a lookup/resolve. We cannot use
    /// `Result<T, E>` or a `try` due to there being two
    /// "success" cases `success` and `ambiguous`.
    enum LookupResult<Value: Equatable>: Equatable {
        /// Found a valid type for the lookup
        case success(Value)
        /// Found a type, but it exists many times
        /// in the environment and is ambiguous on
        /// which one to use.
        case ambiguous(Value)
        /// No column in the environment exists
        case columnDoesNotExist(Substring)
        /// No table in the environment exists
        case tableDoesNotExist(Substring)
        /// No schema in the environment exists
        case schemaDoesNotExist(Substring)
        
        init(_ value: Value, isAmbiguous: Bool) {
            if isAmbiguous {
                self = .ambiguous(value)
            } else {
                self = .success(value)
            }
        }
        
        var value: Value? {
            switch self {
            case .success(let value): value
            case .ambiguous(let value): value
            case .columnDoesNotExist, .tableDoesNotExist, .schemaDoesNotExist: nil
            }
        }
        
        /// Tranforms the wrapped value.
        func map<T>(_ transform: (Value) throws -> T) rethrows -> LookupResult<T> {
            switch self {
            case .success(let value): try .success(transform(value))
            case .ambiguous(let value): try .ambiguous(transform(value))
            case .columnDoesNotExist(let name): .columnDoesNotExist(name)
            case .tableDoesNotExist(let name): .tableDoesNotExist(name)
            case .schemaDoesNotExist(let name): .schemaDoesNotExist(name)
            }
        }
        
        /// Tranforms the wrapped value.
        func mapValue<T>(_ transform: (Value) throws -> LookupResult<T>) rethrows -> LookupResult<T> {
            switch self {
            case .success(let value): try transform(value)
            case .ambiguous(let value): try transform(value)
            case .columnDoesNotExist(let name): .columnDoesNotExist(name)
            case .tableDoesNotExist(let name): .tableDoesNotExist(name)
            case .schemaDoesNotExist(let name): .schemaDoesNotExist(name)
            }
        }
    }
    
    /// A table that has been imported with any addition
    /// metadata we need about the table
    struct ImportedTable: Equatable {
        /// The imported table.
        let table: Table
        /// Some tables bring in extra columns that are not
        /// defined on the table like an `FTS` table bringing
        /// in `rank`. Those can be stored here so the table
        /// can remain intact.
        let additionalColumns: Columns?
        /// Whether or not this table exists optionally in the env.
        /// The `table`s columns have already been adjusted to be
        /// optional. This is just for extra metadata
        let isOptional: Bool
    }
    
    struct Diff {
        let tables: Slice<DuplicateDictionary<QualifiedName, ImportedTable>>
        let values: Slice<DuplicateDictionary<Substring, Type>>
    }
    
    init(parent: Environment? = nil) {
        self.detachedValues.reserveCapacity(20)
        self.parent = parent
    }
    
    /// All columns in the environment and their name
    var allColumns: [(Substring, Type)] {
        detachedValues.map { ($0.key, $0.value) }
    }
    
    /// All columns types in the environment
    var allColumnTypes: [Type] {
        Array(detachedValues.values)
    }
    
    /// All table that have been imported into the environment
    var allImportedTables: [ImportedTable] {
        return importedTables.map(\.value)
    }
    
    func hasColumn(named: Substring) -> Bool {
        return detachedValues[named].count > 0
    }
    
    func resolve(function name: Substring) -> Function? {
        Builtins.functions[name]
    }
    
    func resolve(prefix op: Operator) -> Function? {
        return switch op {
        case .plus: Builtins.pos
        case .minus: Builtins.negate
        case .tilde: Builtins.bitwiseNot
        default: nil
        }
    }
    
    func resolve(infix op: Operator) -> Function? {
        return switch op {
        case .in, .not(.in): Builtins.in
        case .plus, .minus, .multiply, .bitwuseOr,
             .bitwiseAnd, .shl, .shr, .mod:
            Builtins.arithmetic
        case .divide: Builtins.divide
        case .eq, .eq2, .neq, .neq2, .lt, .gt, .lte, .gte, .is,
             .notNull, .notnull, .like, .isNot, .isDistinctFrom,
             .isNotDistinctFrom, .between, .and, .or, .isnull, .not:
            Builtins.comparison
        case .concat: Builtins.concatOp
        case .doubleArrow: Builtins.extract
        case .match: Builtins.match
        case .regexp: Builtins.regexp
        case .arrow: Builtins.extractJson
        case .glob: Builtins.glob
        default: nil
        }
    }
    
    func resolve(postfix op: Operator) -> Function? {
        return switch op {
        case .collate: Builtins.concatOp
        case .escape: Builtins.escape
        case .isnull, .notnull, .notNull: Builtins.isNullPostfix
        default: nil
        }
    }

    /// Imports the table into the environment.
    /// If `isOptional` is true all columns types will be
    /// forced to their optional value.
    /// If `qualifiedAccessOnly` is true the columns will only be
    /// available via qualified access with at least the table
    /// name specified
    mutating func `import`(
        table: Table,
        alias: Substring? = nil,
        isOptional: Bool,
        qualifiedAccessOnly: Bool = false
    ) {
        let importedTable = ImportedTable(
            table: isOptional ? table.mapTypes { $0.coerceToOptional() } : table,
            additionalColumns: table.kind == .fts5 ? ["rank": Column(type: .real)] : nil,
            isOptional: isOptional
        )
        
        if let alias {
            importedTables.append(importedTable, for: QualifiedName(name: alias, schema: nil))
            locallyImportedTables.append(importedTable, for: table.name)
        } else {
            importedTables.append(importedTable, for: table.name)
        }
        
        // Insert the tables type as well so it can be used like a column
        // in `MATCH` and `IN` statements.
        insert(detached: table.name.name, type: table.type, isOptional: false)
        
        // Don't insert columns into detached if they required qualified access
        guard !qualifiedAccessOnly else { return }
        
        for (name, column) in table.columns {
            insert(detached: name, type: column.type, isOptional: isOptional)
        }
        
        if let additionalColumns = importedTable.additionalColumns {
            for (name, column) in additionalColumns {
                insert(detached: name, type: column.type, isOptional: isOptional)
            }
        }
    }
    
    /// Imports all columns into the environment
    mutating func `import`(columns: Columns) {
        for (name, column) in columns {
            insert(detached: name, type: column.type, isOptional: false)
        }
    }
    
    /// Imports a single column into the environment.
    mutating func `import`(column: Substring, with type: Type) {
        insert(detached: column, type: type, isOptional: false)
    }
    
    /// Resolves the table for the given name and schema
    func resolve(table: Substring, schema: Substring?) -> LookupResult<ImportedTable> {
        resolveImported(table: table, schema: schema)
    }
    
    /// Will import all values imported in the `environment` vs `self`
    /// that are not considered "local" to just that scope.
    mutating func importNonLocals(in environment: Environment) {
        add(diff: nonLocalsAdded(in: environment))
    }
    
    /// Gets the diff of the values that were added in `environment` vs `self`
    /// that are not considered "local" to just that scope.
    func nonLocalsAdded(in environment: Environment) -> Diff {
        precondition(
            environment.importedTables.count - importedTables.count >= 0,
            "Invalid usaged, only valid when merging an env that extended self"
        )
        
        precondition(
            environment.detachedValues.count - detachedValues.count >= 0,
            "Invalid usaged, only valid when merging an env that extended self"
        )
        
        let tablesStartOffset = max(importedTables.count - 1, 0)
        let valuesStartOffset = max(detachedValues.count - 1, 0)
        
        return Diff(
            tables: environment.importedTables[tablesStartOffset..<environment.importedTables.count],
            values: environment.detachedValues[valuesStartOffset..<environment.detachedValues.count]
        )
    }
    
    /// Adds in the values from the diff
    mutating func add(diff: Diff) {
        importedTables.append(contentsOf: diff.tables)
        detachedValues.append(contentsOf: diff.values)
    }
    
    /// Resolves the type of the column based off the
    /// column, table and schema names provided
    func resolve(
        column: Substring,
        table: Substring?,
        schema: Substring?
    ) -> LookupResult<Type> {
        if let table {
            if let schema {
                /// Fully qualified schema.table.column
                return resolveImported(table: table, schema: schema)
                    .mapValue { table in
                        resolve(column: column, in: table)
                    }
            } else {
                /// Only have the table, need to figure out which
                /// table it is first.
                return resolveImported(table: table)
                    .mapValue { table in
                        resolve(column: column, in: table)
                    }
            }
        } else {
            /// Only have column, lookup in detached for simplicity
            let entries = detachedValues[column]
            
            guard let column = entries.first else {
                return parent?.resolve(column: column, table: table, schema: schema)
                    ?? .columnDoesNotExist(column)
            }
            
            let isAmbiguous = entries.count > 1
            
            // If its ambiguous make sure to still return the type
            // but alert the caller there is an error.
            if isAmbiguous {
                return .ambiguous(column)
            } else {
                return .success(column)
            }
        }
    }
    
    /// Looks up the column for the given name in the imported table.
    /// If `forceAmbiguous` is `true` then if found it will be `.ambiguous(Type)`
    private func resolve(
        column: Substring,
        in importedTable: ImportedTable,
        forceAmbiguous: Bool = false
    ) -> LookupResult<Type> {
        let entries = importedTable.table.columns[column]
        
        if let column = entries.first {
            return LookupResult(column.type, isAmbiguous: forceAmbiguous || entries.count > 1)
        }
        
        guard let column = importedTable.additionalColumns?[column].first else {
            // If the table does not have it the parent won't either
            return .columnDoesNotExist(column)
        }
        
        return LookupResult(column.type, isAmbiguous: forceAmbiguous)
    }
    
    /// Inserts a type into the map of detached values.
    /// If `isOptional` the type will be forced to optional.
    private mutating func insert(
        detached: Substring,
        type: Type,
        isOptional: Bool
    ) {
        // If the type is already optional no need to force it to T?? since
        // it means nothing to SQLite.
        let type: Type = isOptional ? type.coerceToOptional() : type
        detachedValues.append(type, for: detached)
    }
    
    /// Looks up a table that does not have a schema defined. Applies SQLites
    /// precedence orders to make sure the correc table is returned.
    private func resolveImported(table: Substring) -> LookupResult<ImportedTable> {
        // No schema means it was a CTE or aliased subquery which should take precedence
        let noSchemaEntries = searchForImportedAndLocalTable(named: QualifiedName(name: table, schema: nil))
        if let importedTable = noSchemaEntries.first {
            return LookupResult(importedTable, isAmbiguous: noSchemaEntries.count > 1)
        }
        
        // SQLite actually lets `temp` take precedence over `main` so we need to check it first.
        let tempEntries = searchForImportedAndLocalTable(named: QualifiedName(name: table, schema: .temp))
        if let importedTable = tempEntries.first {
            return LookupResult(importedTable, isAmbiguous: tempEntries.count > 1)
        }
        
        let mainEntries = searchForImportedAndLocalTable(named: QualifiedName(name: table, schema: .main))
        if let importedTable = mainEntries.first {
            return LookupResult(importedTable, isAmbiguous: mainEntries.count > 1)
        }
        
        return parent?.resolveImported(table: table) ?? .tableDoesNotExist(table)
    }
    
    private func resolveImported(
        table: Substring,
        schema: Substring?
    ) -> LookupResult<ImportedTable> {
        guard let schema else {
            return resolveImported(table: table)
        }
        
        guard let schemaName = SchemaName(schema) else {
            return .schemaDoesNotExist(schema)
        }
        
        let qualifiedName = QualifiedName(name: table, schema: schemaName)
        let entries = searchForImportedAndLocalTable(named: qualifiedName)
        
        guard let importedTable = entries.first else {
            return parent?.resolveImported(table: table, schema: schema)
                ?? .tableDoesNotExist(table)
        }
        
        let isAmbiguous = entries.count > 1
        
        if isAmbiguous {
            return .ambiguous(importedTable)
        } else {
            return .success(importedTable)
        }
    }
    
    /// Searchs for the table name in both the `importedTables` and if it
    /// is not found will then search in `locallyImportedTables`
    private func searchForImportedAndLocalTable(
        named name: QualifiedName
    ) -> DuplicateDictionary<QualifiedName, ImportedTable>.Entries {
        let imported = importedTables[name]
        
        if !imported.isEmpty {
            return imported
        } else {
            return locallyImportedTables[name]
        }
    }
}

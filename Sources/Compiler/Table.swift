//
//  Table.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/2/25.
//

/// A table within the database schema
public struct Table: Sendable, Equatable {
    /// The name of the table
    public var name: QualifiedName
    /// The columns of the table
    public var columns: Columns
    /// The columns that make up the primary key
    public let primaryKey: [Substring]
    /// What kind of table it is (FTS/CTE...)
    public let kind: Kind
    
    public enum Kind: Sendable {
        case normal
        case view
        case fts5
        case cte
        case subquery
    }
    
    init(
        name: QualifiedName,
        columns: Columns,
        primaryKey: [Substring] = [],
        kind: Kind
    ) {
        self.name = name
        self.columns = columns
        self.primaryKey = primaryKey
        self.kind = kind
    }
    
    var type: Type {
        return .row(.fixed(columns.map(\.value.type)))
    }
    
    /// A set of all required columns that need to be set on insert
    var nonGeneratedColumns: [(Substring, Column)] {
        return columns.reduce(into: []) { result, column in
            guard !column.value.isGenerated else { return }
            result.append((column.key, column.value))
        }
    }
    
    /// A set of all required columns that need to be set on insert
    var requiredColumnsNames: Set<Substring> {
        return columns.reduce(into: []) { result, column in
            guard column.value.isRequired else { return }
            result.insert(column.key)
        }
    }
    
    /// A table to be returned incase of an error in type checking
    static let error = Table(
        name: QualifiedName(name: "<<error>>", schema: nil),
        columns: [:],
        primaryKey: [],
        kind: .normal
    )
    
    /// The table but with the name of the alias.
    /// Used in `FROM foo AS bar`
    func aliased(to alias: Substring) -> Table {
        var copy = self
        // Alias erases schema on purpose.
        // main.foo AS bar does not equal main.bar
        copy.name = QualifiedName(name: alias, schema: nil)
        return copy
    }
    
    /// Function to map over the column types and perform any
    /// transformations needed
    func mapTypes(_ transform: (Type) -> Type) -> Table {
        var copy = self
        copy.columns = columns.mapValues { $0.mapType(transform) }
        return copy
    }
}

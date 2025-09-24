//
//  Statement.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/14/25.
//

public struct Statement {
    /// The information in the `DEFINE` statement if it exists
    public let definition: Definition?
    /// Any bind parameters for the statement
    public let parameters: [Parameter<String>]
    /// The return type if any.
    public let resultColumns: ResultColumns
    /// How many possible items will be in the result set.
    public let outputCardinality: Cardinality
    /// `false` if the statement edits the schema
    /// or changes any rows in a table.
    public let isReadOnly: Bool
    /// The statement source with all extra SQL syntax removed
    /// that is not valid in SQLite but valid in this library
    public let sanitizedSource: String
    /// The source broken up into segments.
    public let sourceSegments: [SourceSegment]
    /// Any table that were accessed and used in the query.
    public let usedTableNames: Set<Substring>
    /// The syntax associated to the statement
    let syntax: any StmtSyntax
    
    /// If `true` the query returns nothing.
    public var noOutput: Bool {
        return resultColumns.isEmpty
    }
    
    /// The name if one was defined
    public var name: Substring? {
        return definition?.name
    }
    
    /// Whether or not the source syntax is an INSERT statement
    public var isInsert: Bool {
        if syntax is InsertStmtSyntax { return true }
        guard let definition = syntax as? QueryDefinitionStmtSyntax else { return false }
        return definition.statement is InsertStmtSyntax
    }
    
    /// Replaces the definition with the given input
    public func with(definition: Definition?) -> Statement {
        return Statement(
            definition: definition,
            parameters: parameters,
            resultColumns: resultColumns,
            outputCardinality: outputCardinality,
            isReadOnly: isReadOnly,
            sanitizedSource: sanitizedSource,
            sourceSegments: sourceSegments,
            usedTableNames: usedTableNames,
            syntax: syntax
        )
    }
}

/// An input parameter for a query.
public struct Parameter<Name> {
    /// The type of the input
    public let type: Type
    /// The bind parameter index SQLite is expecting
    public let index: Int
    /// The explicit or inferred name of the parameter.
    public let name: Name
    /// Any place in the source the parameter exists
    public let locations: [SourceLocation]
    
    func with<NewName>(name: NewName) -> Parameter<NewName> {
        return Parameter<NewName>(
            type: type,
            index: index,
            name: name,
            locations: locations
        )
    }
}

/// The values from a `DEFINE QUERY` statement
public struct Definition {
    public let name: Substring
    public let input: Substring?
    public let output: Substring?
}

/// The output of a statement
public struct ResultColumns: Sendable {
    public let chunks: [Chunk]
    
    public static let empty = ResultColumns(chunks: [])
   
    /// A group of columns in the result that can be grouped together.
    /// Each group is either a `table.*` or an explicit list of columns
    /// before or after.
    ///
    /// Allows us to return the table model nested within the output.
    ///
    /// Example:
    /// ```
    /// SELECT foo.*, bar.*, bar.baz + 1 AS extra FROM ...
    /// ```
    ///
    /// Would generate:
    /// ```
    /// struct Output {
    ///     let foo: Foo
    ///     let bar: Bar
    ///     let extra: Int
    /// }
    /// ```
    ///
    /// Where `foo.*`, `bar.*`, and `extra` are each their own chunk.
    public struct Chunk: Sendable {
        /// The list of columns returned
        public let columns: Columns
        /// The source table this should be mapped too.
        /// If the user does a `SELECT * FROM foo` we can
        /// just return a `Foo` object rather than generate
        /// a specific type for the output of the `SELECT`.
        /// If the `SELECT` does not map directly to a table
        /// due to selecting from many columns from many tables
        /// this will be `nil`.
        public let table: Substring?
        /// If the table is joined in with an OUTER join or something
        /// similar that does not require a match it is optional
        public let isTableOptional: Bool
        
        public init(
            columns: Columns,
            table: Substring?,
            isTableOptional: Bool = false
        ) {
            self.columns = columns
            self.table = table
            self.isTableOptional = isTableOptional
        }
    }
    
    public init(chunks: [Chunk]) {
        self.chunks = chunks
    }
    
    public init(
        columns: Columns,
        table: Substring?,
        isTableOptional: Bool = false
    ) {
        self.chunks = [Chunk(columns: columns, table: table, isTableOptional: isTableOptional)]
    }
    
    /// The columns as a row type.
    public var type: Type {
        return .row(.fixed(allColumns.map(\.value.type)))
    }
    
    /// Whether or not there are any columns returned
    public var isEmpty: Bool {
        return chunks.isEmpty || chunks.allSatisfy(\.columns.isEmpty)
    }
    
    /// How many columns there are total
    public var count: Int {
        return chunks.reduce(0) { $0 + $1.columns.count }
    }
    
    /// All of the columns in all of the chunks
    public var allColumns: Columns {
        // If there is only one chunk just hand back its columns
        if chunks.count == 1, let onlyChunk = chunks.first {
            return onlyChunk.columns
        }
        
        return chunks.reduce(into: [:]) { result, chunk in
            for column in chunk.columns {
                result.append(column.value, for: column.key)
            }
        }
    }
    
    public func mapTypes(_ transform: (Type) -> Type) -> ResultColumns {
        return ResultColumns(
            chunks: chunks.map { chunk in
                Chunk(
                    columns: chunk.columns.mapValues{ $0.mapType(transform) },
                    table: chunk.table,
                    isTableOptional: chunk.isTableOptional
                )
            }
        )
    }
}

/// The different segments of the source SQL.
/// Some bits of the SQL need to get written at
/// runtime for things like parameters that
/// are a list/row. Since we need to add `?`'s
/// for each of the inputs.
///
/// This breaks it up into the known/unknown parts.
public enum SourceSegment {
    /// Just a portion of the text that makes up the statement
    case text(Substring)
    /// A spot where a row/list parameter exists which needs
    /// to be written at runtime.
    ///
    /// The original source for the bind parameter has already
    /// been removed from the preceding `text` segment
    case rowParam(Parameter<String>)
    
    public var text: Substring? {
        if case let .text(s) = self { return s }
        return nil
    }
}

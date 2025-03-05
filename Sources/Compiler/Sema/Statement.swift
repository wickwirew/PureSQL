//
//  Statement.swift
//  Feather
//
//  Created by Wes Wickwire on 2/14/25.
//

public struct Statement {
    public let name: Substring?
    /// Any bind parameters for the statement
    public let parameters: [Int: Parameter<String>]
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
    /// The source syntax
    let syntax: any StmtSyntax
    
    /// If `true` the query returns nothing.
    public var noOutput: Bool {
        return resultColumns.columns.isEmpty
    }
    
    /// Replaces the name with the given input
    public func with(name: Substring?) -> Statement {
        return Statement(
            name: name,
            parameters: parameters,
            resultColumns: resultColumns,
            outputCardinality: outputCardinality,
            isReadOnly: isReadOnly,
            sanitizedSource: sanitizedSource,
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
    public let ranges: [Range<Substring.Index>]
    
    func with<NewName>(name: NewName) -> Parameter<NewName> {
        return Parameter<NewName>(
            type: type,
            index: index,
            name: name,
            ranges: ranges
        )
    }
}

/// The output of a statement
public struct ResultColumns: Sendable {
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
    
    /// The columns as a row type.
    public var type: Type {
        return .row(.named(columns))
    }
    
    public static let empty = ResultColumns(columns: [:], table: nil)
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
}

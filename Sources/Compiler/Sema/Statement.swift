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
    public let output: Type?
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
        return output == nil || output == .row(.empty)
    }
    
    /// Replaces the name with the given input
    public func with(name: Substring?) -> Statement {
        return Statement(
            name: name,
            parameters: parameters,
            output: output,
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
    
    func with<NewName>(name: NewName) -> Parameter<NewName> {
        return Parameter<NewName>(type: type, index: index, name: name)
    }
}

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
    
    public let isReadOnly: Bool
    
    public let sanitizedSource: String
    
    let syntax: any StmtSyntax
    
    public var range: Range<Substring.Index> {
        return syntax.range
    }
    
    /// If `true` the query returns nothing.
    public var noOutput: Bool {
        return output == nil || output == .row(.empty)
    }
    
    /// If the syntax is a query definition
    /// e.g. DEFINE QUERY fetchUser AS
    /// It will return the range of the inner query
    /// without the DEFINE... part.
    public var rangeWithoutDefinition: Range<Substring.Index> {
        if let definition = syntax as? QueryDefinitionStmtSyntax {
            return definition.statement.range
        } else {
            return syntax.range
        }
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
    
    /// Will get the type for the bind parameter at the given index
    public func type(for index: Int) -> Type? {
        return parameters[index]?.type
    }
    
    /// Will get the type for the bind parameter bound to the given name.
    public func type(for name: Substring) -> Type? {
        guard let (index, _) = parameters
            .first(where: { $1.name == name }) else { return nil }
        
        return type(for: index)
    }
    
    /// Will return the inferred name for the bind parameter at the given index.
    /// The name will not be unique, if two are inferred to have `bar` both will
    /// return `bar` at this point.
    public func name(for index: Int) -> String? {
        return parameters[index]?.name
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

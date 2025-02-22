//
//  Statement.swift
//  Feather
//
//  Created by Wes Wickwire on 2/14/25.
//

public struct Statement {
    public let name: Substring?
    public let signature: Signature
    let syntax: any StmtSyntax
    public let isReadOnly: Bool
    public let sanitizedSource: String
    
    public var range: Range<Substring.Index> {
        return syntax.range
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
            signature: signature,
            syntax: syntax,
            isReadOnly: isReadOnly,
            sanitizedSource: sanitizedSource
        )
    }
}

//
//  Symbols.swift
//  Feather
//
//  Created by Wes Wickwire on 2/14/25.
//

public struct Statement {
    public let name: Substring?
    public let signature: Signature
    let syntax: any StmtSyntax
    
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
}

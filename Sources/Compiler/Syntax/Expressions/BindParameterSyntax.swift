//
//  BindParameterSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct BindParameterSyntax: ExprSyntax, Hashable, CustomStringConvertible {
    let id: SyntaxId
    let kind: Kind
    let index: Index
    let location: SourceLocation
    
    typealias Index = Int
    
    enum Kind: Hashable {
        case named(IdentifierSyntax)
        case unnamed
    }
    
    var description: String {
        return switch kind {
        case let .named(name): name.description
        case .unnamed: "?"
        }
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

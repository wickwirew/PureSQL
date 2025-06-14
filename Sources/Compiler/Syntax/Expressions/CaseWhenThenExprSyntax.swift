//
//  CaseWhenThenExprSyntax.swift
//  Feather
//
//  Created by Wes Wickwire on 5/7/25.
//

struct CaseWhenThenExprSyntax: ExprSyntax {
    let id: SyntaxId
    let `case`: (any ExprSyntax)?
    let whenThen: [WhenThen]
    let `else`: (any ExprSyntax)?
    let location: SourceLocation
    
    struct WhenThen {
        let when: any ExprSyntax
        let then: any ExprSyntax
    }
    
    func accept<V: ExprSyntaxVisitor>(visitor: inout V) -> V.ExprOutput {
        return visitor.visit(self)
    }
}

extension CaseWhenThenExprSyntax: CustomStringConvertible {
    var description: String {
        var str = "CASE"
        if let `case` {
            str += " \(`case`)"
        }
        for whenThen in whenThen {
            str += " WHEN \(whenThen.when) THEN \(whenThen.then)"
        }
        if let `else` {
            str += " ELSE \(`else`)"
        }
        str += " END"
        return str
    }
}

//
//  Definition.swift
//  Feather
//
//  Created by Wes Wickwire on 2/14/25.
//

struct QueryDefinition: Stmt {
    let name: Identifier
    let statement: any Stmt
    let range: Range<String.Index>
    
    func accept<V>(visitor: inout V) -> V.StmtOutput where V : StmtVisitor {
        return visitor.visit(self)
    }
}

//
//  Symbols.swift
//  Feather
//
//  Created by Wes Wickwire on 2/14/25.
//

struct Statement {
    let name: Substring?
    let signature: Signature
    let syntax: any StmtSyntax
}

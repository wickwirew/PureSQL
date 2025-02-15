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
}

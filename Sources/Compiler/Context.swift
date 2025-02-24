//
//  Context.swift
//  Feather
//
//  Created by Wes Wickwire on 2/23/25.
//

struct Context {
    private(set) var schema = Schema()
    
    private var types: [SyntaxId: Type] = [:]
    
    private var signatures: [SyntaxId: Signature] = [:]
}

//
//  Plugins.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import SwiftSyntaxMacros
import SwiftCompilerPlugin

@main
struct FeatherPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        QueryMacro.self,
        DatabaseMacro.self,
    ]
}

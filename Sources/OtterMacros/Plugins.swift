//
//  Plugins.swift
//  Otter
//
//  Created by Wes Wickwire on 5/10/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct OtterPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        QueryMacro.self,
        DatabaseMacro.self,
    ]
}

//
//  Plugins.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/10/25.
//

import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct PureSQLPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        QueryMacro.self,
        DatabaseMacro.self,
    ]
}

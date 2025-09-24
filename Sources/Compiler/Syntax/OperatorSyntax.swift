//
//  OperatorSyntax.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/7/25.
//

/// https://www.sqlite.org/lang_expr.html
struct OperatorSyntax: CustomStringConvertible, Syntax {
    let id: SyntaxId
    let `operator`: Operator
    let location: SourceLocation

    var description: String {
        return `operator`.description
    }
}

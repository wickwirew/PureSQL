//
//  SyntaxError.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/10/25.
//

struct SyntaxError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

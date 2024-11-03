//
//  Diagnostics.swift
//
//
//  Created by Wes Wickwire on 10/21/24.
//

import Schema

public struct Diagnostic: Error {
    public let message: String
    public let range: Range<String.Index>
    public let suggestion: String?
    
    public init(
        _ message: String,
        at range: Range<String.Index>,
        suggestion: String? = nil
    ) {
        self.message = message
        self.range = range
        self.suggestion = suggestion
    }
    
    public init(
        expected: TypeName,
        got actual: TypeName,
        at range: Range<String.Index>
    ) {
        self.message = "Incorrect type, expected '\(expected.name)' got '\(actual.name)'"
        self.range = range
        self.suggestion = expected.name.description
    }
    
    static func placeholder(name: String) -> String {
        // So Xcode doesnt make this a placeholder
        return "<\("#name#>")"
    }
}

extension Diagnostic {
    static func incorrectType(
        _ actual: TypeName,
        expected: TypeName,
        at range: Range<String.Index>
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected '\(expected.name)' got '\(actual.name)'",
            at: range,
            suggestion: expected.name.description
        )
    }
    
    static func expectedNumber(
        _ actual: TypeName,
        at range: Range<String.Index>
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected number got '\(actual.name)'",
            at: range
        )
    }
}

public struct Diagnostics {
    private(set) var diagnostics: [Diagnostic] = []
    
    public init(diagnostics: [Diagnostic] = []) {
        self.diagnostics = diagnostics
    }
    
    public mutating func add(_ diagnostic: Diagnostic) {
#if DEBUG
        print(diagnostic.message)
#endif
        
        diagnostics.append(diagnostic)
    }
    
    public mutating func throwing(_ diagnostic: Diagnostic) throws {
        diagnostics.append(diagnostic)
        throw diagnostic
    }
}

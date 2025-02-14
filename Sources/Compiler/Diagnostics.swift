//
//  Diagnostics.swift
//
//
//  Created by Wes Wickwire on 10/21/24.
//

public struct Diagnostic: Error {
    public let message: String
    public let range: Range<String.Index>
    public let suggestion: Suggestion?
    
    public enum Suggestion: Sendable {
        case replace(String)
        case append(String)
    }
    
    public init(
        _ message: String,
        at range: Range<String.Index>,
        suggestion: Suggestion? = nil
    ) {
        self.message = message
        self.range = range
        self.suggestion = suggestion
    }
    
    init(
        expected: TypeNameSyntax,
        got actual: TypeNameSyntax,
        at range: Range<String.Index>
    ) {
        self.message = "Incorrect type, expected '\(expected.name)' got '\(actual.name)'"
        self.range = range
        self.suggestion = .replace(expected.name.description)
    }
    
    static func placeholder(name: String) -> String {
        // So Xcode doesnt make this a placeholder
        return "<\("#name#>")"
    }
}

extension Diagnostic {
    static func incorrectType(
        _ actual: TypeNameSyntax,
        expected: TypeNameSyntax,
        at range: Range<String.Index>
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected '\(expected.name)' got '\(actual.name)'",
            at: range,
            suggestion: .replace(expected.name.description)
        )
    }
    
    static func expectedNumber(
        _ actual: TypeNameSyntax,
        at range: Range<String.Index>
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected number got '\(actual.name)'",
            at: range
        )
    }
    
    static func ambiguous(
        _ identifier: Substring,
        at range: Range<String.Index>
    ) -> Diagnostic {
        Diagnostic(
            "'\(identifier)' is ambigious in the current context",
            at: range
        )
    }
    
    static func tableDoesNotExist(_ identifier: IdentifierSyntax) -> Diagnostic {
        Diagnostic(
            "Table '\(identifier)' does not exist",
            at: identifier.range
        )
    }
    
    static func columnDoesNotExist(_ identifier: IdentifierSyntax) -> Diagnostic {
        Diagnostic(
            "Column '\(identifier)' does not exist",
            at: identifier.range
        )
    }
    
    static func nameRequired(at range: Range<Substring.Index>) -> Diagnostic {
        return Diagnostic(
            "Name required, add via 'AS'",
            at: range,
            suggestion: .append("AS \(Diagnostic.placeholder(name: "name"))")
        )
    }
    
    static func unexpectedToken(
        of kind: Token.Kind,
        expected: Token.Kind? = nil,
        at range: Range<Substring.Index>
    ) -> Diagnostic {
        if let expected {
            return Diagnostic("Unexpected token \(kind), expected '\(expected)'", at: range)
        } else {
            return Diagnostic("Unexpected token \(kind)", at: range)
        }
    }
    
    static func unexpected(token: Token) -> Diagnostic {
        return unexpectedToken(of: token.kind, at: token.range)
    }
    
    static func unexpectedToken(
        of kind: Token.Kind,
        expectedAnyOf expected: Token.Kind...,
        at range: Range<Substring.Index>
    ) -> Diagnostic {
        var expectedMessage = ""
        for (index, kind) in expected.enumerated() {
            if index == expected.count {
                expectedMessage += "or "
            } else if index > 0 {
                expectedMessage += ", "
            }
            
            expectedMessage += "'\(kind)'"
        }
        
        return Diagnostic("Unexpected token \(kind), expected any of \(expected)", at: range)
    }
}

public struct Diagnostics {
    public private(set) var diagnostics: [Diagnostic] = []
    
    public init(diagnostics: [Diagnostic] = []) {
        self.diagnostics = diagnostics
    }
    
    @discardableResult
    public mutating func add(_ diagnostic: Diagnostic) -> Diagnostic {
        diagnostics.append(diagnostic)
        return diagnostic
    }
    
    // TODO: Rename to `merge`
    public mutating func add(contentsOf diagnostics: Diagnostics) {
        self.diagnostics.append(contentsOf: diagnostics.diagnostics)
    }
    
    public mutating func throwing(_ diagnostic: Diagnostic) throws {
        diagnostics.append(diagnostic)
        throw diagnostic
    }
    
    public mutating func trying<Output>(
        _ action: () throws -> Output,
        at range: Range<Substring.Index>
    ) -> Output? {
        do {
            return try action()
        } catch {
            add(.init("\(error)", at: range))
            return nil
        }
    }
}

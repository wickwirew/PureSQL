//
//  Diagnostic.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

public struct Diagnostic: Error {
    public let message: String
    public let level: Level
    public let location: SourceLocation
    public let suggestion: Suggestion?
    
    public enum Suggestion: Sendable {
        case replace(String)
        case append(String)
    }
    
    public enum Level: Sendable {
        case warning
        case error
    }
    
    public init(
        _ message: String,
        level: Level = .error,
        at location: SourceLocation,
        suggestion: Suggestion? = nil
    ) {
        self.message = message
        self.level = level
        self.location = location
        self.suggestion = suggestion
    }

    static func placeholder(name: String) -> String {
        // So Xcode doesnt make this a placeholder
        return "<\("#name#>")"
    }
}

extension Diagnostic: CustomStringConvertible {
    public var description: String {
        return message
    }
}

extension Diagnostic {
    static func incorrectType(
        _ actual: TypeNameSyntax,
        expected: TypeNameSyntax,
        at location: SourceLocation
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected '\(expected.name)' got '\(actual.name)'",
            at: location,
            suggestion: .replace(expected.name.description)
        )
    }
    
    static func expectedNumber(
        _ actual: TypeNameSyntax,
        at location: SourceLocation
    ) -> Diagnostic {
        Diagnostic(
            "Incorrect type, expected number got '\(actual.name)'",
            at: location
        )
    }
    
    static func ambiguous(
        _ identifier: Substring,
        at location: SourceLocation
    ) -> Diagnostic {
        Diagnostic(
            "'\(identifier)' is ambigious in the current context",
            at: location
        )
    }
    
    static func tableAlreadyExists(_ identifier: IdentifierSyntax) -> Diagnostic {
        Diagnostic(
            "Table '\(identifier)' already exists",
            at: identifier.location
        )
    }
    
    static func tableDoesNotExist(_ table: Substring, at location: SourceLocation) -> Diagnostic {
        Diagnostic(
            "Table '\(table)' does not exist",
            at: location
        )
    }
    
    static func tableDoesNotExist(_ identifier: IdentifierSyntax) -> Diagnostic {
        .tableDoesNotExist(identifier.value, at: identifier.location)
    }
    
    static func columnDoesNotExist(_ column: Substring, at location: SourceLocation) -> Diagnostic {
        Diagnostic(
            "Column '\(column)' does not exist",
            at: location
        )
    }
    
    static func columnDoesNotExist(_ identifier: IdentifierSyntax) -> Diagnostic {
        .columnDoesNotExist(identifier.value, at: identifier.location)
    }
    
    static func schemaDoesNotExist(_ schema: Substring, at location: SourceLocation) -> Diagnostic {
        Diagnostic(
            "Schema '\(schema)' does not exist",
            at: location
        )
    }
    
    static func schemaDoesNotExist(_ identifier: IdentifierSyntax) -> Diagnostic {
        .schemaDoesNotExist(identifier.value, at: identifier.location)
    }
    
    static func unexpectedToken(
        of kind: Token.Kind,
        expected: Token.Kind? = nil,
        at location: SourceLocation
    ) -> Diagnostic {
        if let expected {
            return Diagnostic("Unexpected token \(kind), expected '\(expected)'", at: location)
        } else {
            return Diagnostic("Unexpected token \(kind)", at: location)
        }
    }
    
    static func unexpected(token: Token) -> Diagnostic {
        return unexpectedToken(of: token.kind, at: token.location)
    }
    
    static func unexpectedToken(
        of kind: Token.Kind,
        expectedAnyOf expected: Token.Kind...,
        at location: SourceLocation
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
        
        return Diagnostic("Unexpected token \(kind), expected any of \(expected)", at: location)
    }
    
    static func illegalStatement(
        in context: String,
        at location: SourceLocation
    ) -> Diagnostic {
        return Diagnostic("Statement is not allowed in \(context)", at: location)
    }
    
    static func alreadyHasPrimaryKey(
        _ table: Substring,
        at location: SourceLocation
    ) -> Diagnostic {
        return Diagnostic("Table '\(table)' already has a primary key", at: location)
    }
    
    static func unableToUnify(
        _ t1: Type,
        with t2: Type,
        at location: SourceLocation
    ) -> Diagnostic {
        return Diagnostic("Unable to unify types '\(t1)' and '\(t2)'", at: location)
    }
}

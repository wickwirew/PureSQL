//
//  Syntax+Extensions.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntaxMacros

extension VariableDeclSyntax {
    /// Searchs the variable decl for the `@Query` macro and gets the input
    /// arguments and performs any validation.
    func queryMacroInputsIfIsQuery(in context: some MacroExpansionContext) -> (
        source: String,
        inputName: String?,
        outputName: String?
    )? {
        for attribute in attributes {
            switch attribute {
            case .attribute(let attribute):
                guard attribute.attributeName.tokens(viewMode: .all)
                    .map(\.tokenKind) == [.identifier("Query")] else { continue }
                
                guard case let .argumentList(argumentList) = attribute.arguments else {
                    context.addDiagnostics(from: SyntaxError("Query is missing arguments"), node: attribute)
                    return nil
                }
                
                var arguments = argumentList.makeIterator()
                
                guard let source = arguments.next()?.expression
                    .validateIsStringLiteral(in: context) else { return nil }
                
                var inputType, outputType: ExprSyntax?
                let secondArg = arguments.next()
                
                if secondArg?.label?.tokenKind == .identifier("inputName") {
                    inputType = secondArg?.expression
                }
                
                let maybeOutputTypeArg = inputType == nil ? secondArg : arguments.next()
                if maybeOutputTypeArg?.label?.tokenKind == .identifier("outputName") {
                    inputType = maybeOutputTypeArg?.expression
                }
                
                return (
                    source.getStringAndValidateHasNoInterpolation(in: context),
                    inputType?.validateIsStringLiteral(in: context)?
                        .getStringAndValidateHasNoInterpolation(in: context),
                    outputType?.validateIsStringLiteral(in: context)?
                        .getStringAndValidateHasNoInterpolation(in: context)
                )
            default:
                break
            }
        }
        
        return nil
    }
    
    var getter: CodeBlockItemListSyntax? {
        for binding in bindings {
            guard let accessorBlock = binding.accessorBlock,
                  // TODO: Handle explicit `get {}`, seems different than the `.getter`
                  case let .getter(getter) = accessorBlock.accessors else { return nil }
            return getter
        }
        
        return nil
    }
    
    func asMigrationsArray(in context: some MacroExpansionContext) -> [(String, ExprSyntax)] {
        var strings: [(String, ExprSyntax)] = []
        
        guard let getter else {
            context.addDiagnostics(from: SyntaxError("Must have a getter that returns [String]"), node: self)
            return strings
        }
        
        guard let stmt = getter.last?.item, getter.count == 1 else {
            context.addDiagnostics(from: SyntaxError("Migrations must have one statement returning [String]"), node: self)
            return strings
        }
        
        guard let ret = stmt.as(ReturnStmtSyntax.self) else {
            context.addDiagnostics(from: SyntaxError("Must be return statement"), node: self)
            return strings
        }
        
        guard let array = ret.expression?.as(ArrayExprSyntax.self) else {
            context.addDiagnostics(from: SyntaxError("Migrations must return an array literal"), node: self)
            return strings
        }
        
        for element in array.elements {
            guard let string = element.expression
                .validateIsStringLiteral(in: context)?
                .getStringAndValidateHasNoInterpolation(in: context) else { continue }
            
            strings.append((string, element.expression))
        }

        return strings
    }
}

extension StringLiteralExprSyntax {
    func getStringAndValidateHasNoInterpolation(
        in context: some MacroExpansionContext
    ) -> String {
        var string: String = ""
        
        for segment in segments {
            switch segment {
            case .stringSegment(let s):
                string.append(s.content.text)
            case .expressionSegment(let e):
                context.addDiagnostics(from: SyntaxError("Cannot have any interpolated values"), node: e)
            }
        }
        
        return string
    }
}

extension ExprSyntax {
    func validateIsStringLiteral(in context: some MacroExpansionContext) -> StringLiteralExprSyntax? {
        guard let string = self.as(StringLiteralExprSyntax.self) else {
            context.addDiagnostics(from: SyntaxError("Must be string literal"), node: self)
            return nil
        }
        
        return string
    }
}

extension MemberBlockSyntax {
    /// Gets a dictionary of all of the variables declared.
    func variableDecls() -> [String: VariableDeclSyntax] {
        var result: [String: VariableDeclSyntax] = [:]
        
        for member in members {
            guard let decl = member.decl.as(VariableDeclSyntax.self) else { continue }
            
            for binding in decl.bindings {
                guard let ident = binding.pattern
                    .as(IdentifierPatternSyntax.self)?.identifier.text else { break }
                result[ident] = decl
                break
            }
        }
        
        return result
    }
}

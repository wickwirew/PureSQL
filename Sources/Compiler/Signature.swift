//
//  Signature.swift
//  Feather
//
//  Created by Wes Wickwire on 2/15/25.
//

import OrderedCollections

/// Signature defines the input and output types
/// of a statement. Each input or parameters refers to
/// an explicit bind parameter of the query.
/// The output type is inferred based of the expression.
public struct Signature: CustomReflectable {
    /// Any bind parameters for the statement
    public var parameters: [Int: Parameter]
    /// The return type if any.
    public var output: Type?
    
    static var empty: Signature {
        return Signature(parameters: [:])
    }
    
    var isEmpty: Bool {
        return parameters.isEmpty && output == nil
    }
    
    public var customMirror: Mirror {
        // Helps the CHECK statements in the tests since the `Type`
        // structure is fairly complex and has lots of nesting.
        let outputTypes: [String] = if case let .row(.named(columns)) = output {
            columns.elements.map { "\($0) \($1)" }
        } else {
            []
        }
        
        return Mirror(
            self,
            children: [
                "parameters": parameters.values
                    .map(\.self)
                    .sorted(by: { $0.index < $1.index }),
                "output": outputTypes,
            ]
        )
    }
}

/// An input parameter for a query.
public struct Parameter {
    /// The type of the input
    public let type: Type
    /// The bind parameter index SQLite is expecting
    public let index: Int
    /// The explicit or inferred name of the parameter.
    public let name: Substring?
}

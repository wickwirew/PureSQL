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
    public var parameters: [Int: Parameter<Substring?>]
    /// The return type if any.
    public var output: Type?
    /// TODO: Add this logic. Adding temporarily as a constant
    /// so it can be used in code gen
    public let outputIsSingleElement = false
    
    static var empty: Signature {
        return Signature(parameters: [:])
    }
    
    public var isEmpty: Bool {
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
    
    /// The parameters don't come with names out of the gate
    /// if one cannot be inferred or was defined explicitly.
    /// This will return the parameters with explicit unique names.
    public var parametersWithNames: [Parameter<String>] {
        var seenNames: Set<String> = []
        var valueIndexStart = 0
        var result: [Parameter<String>] = []
        
        for parameter in parameters.values {
            if let name = parameter.name {
                let name = name.description
                seenNames.insert(name)
                result.append(parameter.with(name: name))
            } else {
                // Technically someone can name a variable
                // `value32` manually so we cannot assume it
                // is available.
                var name: String? = nil
                for i in valueIndexStart..<Int.max {
                    let potential = i == 0 ? "value" : "value\(i)"
                    if !seenNames.contains(potential) {
                        name = potential
                        valueIndexStart = i + 1
                        break
                    }
                }
                
                if let name {
                    seenNames.insert(name)
                    result.append(parameter.with(name: name))
                }
            }
        }
        
        return result
    }
}

/// An input parameter for a query.
public struct Parameter<Name> {
    /// The type of the input
    public let type: Type
    /// The bind parameter index SQLite is expecting
    public let index: Int
    /// The explicit or inferred name of the parameter.
    public let name: Name
    
    func with<NewName>(name: NewName) -> Parameter<NewName> {
        return Parameter<NewName>(type: type, index: index, name: name)
    }
}

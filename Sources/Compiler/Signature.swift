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
    public let parameters: [Int: Parameter<Substring?>]
    /// The return type if any.
    public let output: Type?
    /// How many possible items will be in the result set.
    public let outputCardinality: Cardinality
    
    /// The amount of elements in the result set.
    public enum Cardinality: String {
        case single
        case many
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

    
    /// A default empty signature with no input or output.
    static var empty: Signature {
        return Signature(parameters: [:], output: nil, outputCardinality: .single)
    }
    
    /// Whether or not there is any input or outputs
    public var isEmpty: Bool {
        return parameters.isEmpty && output == nil
    }
    
    /// If `true` the query returns nothing.
    public var noOutput: Bool {
        return output == nil || output == .row(.empty)
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
                "parameters": parametersWithNames,
                "output": outputTypes,
            ]
        )
    }
    
    /// The parameters don't come with names out of the gate
    /// if one cannot be inferred or was defined explicitly.
    /// This will return the parameters with explicit unique names.
    public var parametersWithNames: [Parameter<String>] {
        var seenNames: Set<String> = []
        var result: [Parameter<String>] = []
        
        func uniquify(_ name: String) -> String {
            if !seenNames.contains(name) {
                return name
            }
            
            // Start at two, so we don't have id and id1, id and id2 makes more sense.
            for i in 2..<Int.max {
                let potential = i == 0 ? name : "\(name)\(i)"
                guard !seenNames.contains(potential) else { continue }
                return potential
            }
            
            fatalError("You might want to take it easy on the parameters")
        }
        
        for parameter in parameters.values.sorted(by: { $0.index < $1.index }) {
            if let name = parameter.name {
                // Even inferred names can have collisions.
                // Example: bar = ? AND bar = ? would have 2 named bar.
                let name = uniquify(name.description)
                seenNames.insert(name)
                result.append(parameter.with(name: name))
            } else {
                let name = uniquify("value")
                seenNames.insert(name)
                result.append(parameter.with(name: name))
            }
        }
        
        return result
    }

    /// Will get the type for the bind parameter at the given index
    public func type(for index: Int) -> Type? {
        return parameters[index]?.type
    }
    
    /// Will get the type for the bind parameter bound to the given name.
    public func type(for name: Substring) -> Type? {
        guard let (index, _) = parameters
            .first(where: { $1.name == name }) else { return nil }
        
        return type(for: index)
    }
    
    /// Will return the inferred name for the bind parameter at the given index.
    /// The name will not be unique, if two are inferred to have `bar` both will
    /// return `bar` at this point.
    public func name(for index: Int) -> Substring? {
        return parameters[index]?.name
    }
}

//
//  Function.swift
//  Feather
//
//  Created by Wes Wickwire on 6/7/25.
//

/// A function that is callable from SQL
struct Function: Sendable {
    /// While SQL functions are not explicitly noted as generic we will treat them
    /// as such to retain the type as much as possible. Allows us to have one plus
    /// function that can do `INT + REAL = REAL` sort of things.
    ///
    /// These values will be inferred upon initialization based off of
    /// the `params` and `result`
    let genericTypes: [TypeVariable]
    /// The parameter types these take in
    let params: [Type]
    /// The return type
    let result: Type
    /// Any additional overloads for the function
    let overloads: [Overload]?
    /// Whether or not the function is variadic, meaning the last parameter type
    /// can be added on indefinitely.
    let variadic: Bool
    /// A custom check to be performed during type checking. Allows us to put in
    /// custom error messages and linting if a function has odd usage.
    let check: (@Sendable ([Type], [ExpressionSyntax], SourceLocation, inout Diagnostics) -> Void)?
    
    struct Overload: Sendable {
        let params: [Type]
        let result: Type
        
        init(_ params: Type..., returning result: Type) {
            self.params = params
            self.result = result
        }
    }
    
    init(
        _ params: Type...,
        returning result: Type,
        variadic: Bool = false,
        overloads: [Overload]? = nil,
        check: (@Sendable ([Type], [ExpressionSyntax], SourceLocation, inout Diagnostics) -> Void)? = nil
    ) {
        assert(!(variadic && (overloads?.count ?? 0) > 1), "Cannot have overloads and be variadic")
        
        var genericTypes = params.compactMap(\.typeVariable)
        if let result = result.typeVariable {
            genericTypes.append(result)
        }
        
        
        self.genericTypes = genericTypes.distinct()
        self.params = params
        self.result = result
        self.overloads = overloads
        self.variadic = variadic
        self.check = check
    }
    
    func typeScheme(preferredParameterCount: Int) -> TypeScheme {
        if variadic {
            return expandVariadic(for: preferredParameterCount)
        } else if let overloads {
            if params.count == preferredParameterCount {
                return TypeScheme(
                    typeVariables: genericTypes,
                    type: .fn(params: params, ret: result)
                )
            }
            
            // Find the overload matching the correct parameters. We don't care about
            // overloading based on types.
            for overload in overloads {
                guard overload.params.count == preferredParameterCount else { continue }
                return TypeScheme(
                    typeVariables: genericTypes,
                    type: .fn(params: overload.params, ret: overload.result)
                )
            }
        }
        
        return TypeScheme(
            typeVariables: genericTypes,
            type: .fn(params: params, ret: result)
        )
    }
    
    private func expandVariadic(for count: Int) -> TypeScheme {
        // This is how variadics are handled. If a variadic function is called
        // we extend the signature to match the input count. It is always
        // assumed the last parameter is the variadic.
        let numberOfArgsToAdd = count - params.count
        
        guard count > 0, let last = params.last else {
            return TypeScheme(
                typeVariables: genericTypes,
                type: .fn(params: params, ret: result)
            )
        }
        
        return TypeScheme(
            typeVariables: genericTypes,
            type: .fn(
                params: params + (0..<numberOfArgsToAdd).map { _ in last },
                ret: result
            )
        )
    }
}

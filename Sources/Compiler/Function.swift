//
//  Function.swift
//  Feather
//
//  Created by Wes Wickwire on 6/7/25.
//

struct Function: Sendable {
    let genericTypes: [TypeVariable]
    let params: [Type]
    let result: Type
    let overloads: [Overload]?
    let variadic: Bool
    let check: (@Sendable ([ExpressionSyntax], SourceLocation, inout Diagnostics) -> Void)?
    
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
        check: (@Sendable ([ExpressionSyntax], SourceLocation, inout Diagnostics) -> Void)? = nil
    ) {
        assert(!(variadic && (overloads?.count ?? 0) > 1), "Cannot have overloads and be variadic")
        
        var genericTypes = params.compactMap(\.typeVariable)
        if let result = result.typeVariable {
            genericTypes.append(result)
        }
        
        // TODO: Remove ghetto distinct
        self.genericTypes = Array(Set(genericTypes))
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

//
//  InferenceState.swift
//  Feather
//
//  Created by Wes Wickwire on 2/24/25.
//

/// Manages the state for type inference.
struct InferenceState {
    /// The overall solution
    private(set) var substitution: Substitution = [:]
    /// Any diagnostics that are emitted during inference/unification
    private(set) var diagnostics = Diagnostics()
    /// Number of type variables. Incremented each time a new
    /// fresh type var is created so all are unique
    private var tyVarCounter = 0
    /// Record of known types for certain syntax. These are not
    /// the final type. Once inference has walked the entire
    /// expr `solution(for:)` should be called to apply the final
    /// substitution for the type.
    private var syntaxTypes: [SyntaxId: Type] = [:]
    /// Bind parameters can have `freshTyVar` called multiple times potentially
    /// if its a named parameter used twice. We only want to use one type for
    /// the bind parameter. So this is a map to find the initial syntax
    /// that the bind parameter was assigned a type too. When we lookup the
    /// type for a bind param, we first have to ask this for the syntax id
    /// the bind parameter
    private(set) var bindIndexToSyntaxIds: [BindParameterSyntax.Index: SyntaxId] = [:]
    /// Any locations the bind parameters show up in.
    /// This really isnt the most sensible place for this. May likely break out into its
    /// own thing but keeping it here for now since its so simple.
    private(set) var bindIndexLocations: [BindParameterSyntax.Index: [SourceLocation]] = [:]
    
    /// Instantiates a type scheme by substituting all free type variables
    /// for new fresh type variables.
    mutating func instantiate(_ typeScheme: TypeScheme) -> Type {
        guard !typeScheme.typeVariables.isEmpty else { return typeScheme.type }
        let sub = Substitution(
            typeScheme.typeVariables.map { ($0, freshTyVar()) },
            uniquingKeysWith: { $1 }
        )
        return typeScheme.type.apply(sub)
    }
    
    /// Instantiates the function by substituting all free type variables
    /// for new fresh type variables.
    mutating func instantiate(_ function: Function, preferredArgCount: Int) -> Type {
        return instantiate(function.typeScheme(preferredParameterCount: preferredArgCount))
    }
    
    /// Records the type for a given syntax.
    mutating func record<S: Syntax>(
        type: Type,
        for syntax: borrowing S
    ) {
        syntaxTypes[syntax.id] = type
    }
    
    /// Creates a new nominal type for the syntax
    mutating func nominalType<S: Syntax>(
        of name: Substring,
        for syntax: borrowing S
    ) -> Type {
        let type: Type = .nominal(name)
        syntaxTypes[syntax.id] = type
        return type
    }
    
    /// Creates a new error type for the syntax
    mutating func errorType<S: Syntax>(
        for syntax: borrowing S
    ) -> Type {
        let type: Type = .error
        syntaxTypes[syntax.id] = type
        return type
    }
    
    /// Creates a fresh new unique type variable for a bind parameter.
    mutating func freshTyVar(
        forParam param: borrowing BindParameterSyntax,
        kind: TypeVariable.Kind = .general
    ) -> Type {
        bindIndexLocations[param.index, default: []].append(param.location)
        
        // If there is already a type var for the parameter just reuse it.
        // Named bind parameters can be referenced more than once which
        // could mean it would get multiple type vars
        if let existingId = bindIndexToSyntaxIds[param.index] {
            guard let existingType = syntaxTypes[existingId] else {
                fatalError("Bind Parameter had type assigned, but no type found")
            }
            return solution(for: existingType)
        }
        
        let ty: Type = freshTyVar(kind: kind)
        bindIndexToSyntaxIds[param.index] = param.id
        syntaxTypes[param.id] = ty
        return ty
    }
    
    /// Creates a fresh new unique type variable for the syntax
    mutating func freshTyVar<S: Syntax>(
        for syntax: borrowing S,
        kind: TypeVariable.Kind = .general
    ) -> Type {
        let ty: Type = freshTyVar(kind: kind)
        syntaxTypes[syntax.id] = ty
        return ty
    }
    
    /// Creates a fresh new unique type variable that is not associated
    /// to an explicit syntax.
    mutating func freshTyVar(
        kind: TypeVariable.Kind = .general
    ) -> Type {
        defer { tyVarCounter += 1 }
        return .var(TypeVariable(tyVarCounter, kind: kind))
    }
    
    /// Gives the type a hint
    mutating func hint(
        type hint: Type.Alias.Hint,
        for type: Type,
        at location: SourceLocation
    ) {
        unify(type, with: .alias(type, .hint(hint)), at: location)
    }
    
    /// Gets the final type from the solution for the type if its a ty var.
    /// If `defaultIfTyVar` is true, the type will be given a
    /// default value if it is a type var.
    func solution(for type: Type, defaultIfTyVar: Bool = false) -> Type {
        let result = type.apply(substitution)
        
        guard defaultIfTyVar else {
            return result
        }
        
        switch result {
        case let .var(tv):
            return tv.defaultType
        case let .optional(ty):
            return .optional(solution(for: ty, defaultIfTyVar: true))
        case let .alias(ty, alias):
            return .alias(solution(for: ty, defaultIfTyVar: true), alias)
        case let .row(row):
            if let type = row.first, row.count == 1, !row.isUnknown {
                return solution(for: type, defaultIfTyVar: true)
            } else {
                return .row(row.mapTypes { solution(for: $0, defaultIfTyVar: true) })
            }
        default:
            return result
        }
    }
    
    /// Gets the list of parameters and their solution type.
    /// If `defaultIfTyVar` is true, the type will be given a
    /// default value if it is a type var.
    func parameterSolutions(
        defaultIfTyVar: Bool = false
    ) -> [(index: BindParameterSyntax.Index, type: Type, locations: [SourceLocation])] {
        return bindIndexToSyntaxIds.map { (index, syntaxId) in
            let type = self.syntaxTypes[syntaxId] ?? .error
            let locations = self.bindIndexLocations[index] ?? []
            return (index, solution(for: type, defaultIfTyVar: defaultIfTyVar), locations)
        }
    }
}

// MARK: - Unification

extension InferenceState {
    /// Unifies the two types together so they are considered equal.
    /// If unification fails a diagnostic will be reported.
    mutating func unify(
        _ type: Type,
        with other: Type,
        at location: SourceLocation
    ) {
        // If they are the same, no need to unify
        guard type != other else { return }
        
        switch (type, other) {
        case (.error, _), (_, .error):
            // Already had an upstream error so no need to emit any more diagnostics
            return
            
        case let (.var(tv1), .var(tv2)):
            // Unify to type variables.
            // We need to prioritize what gets substituded for what
            // by its kind.
            // So if we get an `integer` and `float`, we want to promote
            // the `integer` to a `float`, so we sub the int for the float
            if tv1.kind > tv2.kind {
                substitute(tv2, for: type)
            } else {
                substitute(tv1, for: other)
            }
        
        // When two optionals, unify wrapped type.
        case let (.optional(t1), .optional(t2)):
            unify(t1, with: t2, at: location)
            
        // tyVar with optional tyVar
        case let (.var(nonOptional), .optional(.var(optional))):
            let kind = max(nonOptional.kind, optional.kind)
            substitute(nonOptional, for: .optional(.var(optional.with(kind: kind))))
        
        // tyVar with optional tyVar
        case let (.optional(.var(optional)), .var(nonOptional)):
            let kind = max(nonOptional.kind, optional.kind)
            substitute(nonOptional, for: .optional(.var(optional.with(kind: kind))))
            
        // Optional tyVar with concrete type
        case let (.optional(.var(optional)), t):
            substitute(optional, for: .optional(t))
        
        // Optional tyVar with concrete type
        case let (t, .optional(.var(optional))):
            substitute(optional, for: .optional(t))
        
        // tyVar with concrete type
        case let (.var(tv), ty):
            validateCanUnify(type: ty, with: tv.kind, at: location)
            substitute(tv, for: ty)
        
        // tyVar with concrete type
        case let (ty, .var(tv)):
            validateCanUnify(type: ty, with: tv.kind, at: location)
            substitute(tv, for: ty)
            
        case (.integer, .real), (.real, .integer), (.any, _), (_, .any), (.text, .blob), (.blob, .text):
            return // Not equal but valid to use together
            
        case let (.fn(args1, ret1), .fn(args2, ret2)) where args1.count == args2.count:
            unify(args1, with: args2, at: location)
            unify(ret1.apply(substitution), with: ret2.apply(substitution), at: location)
            
        // Row with value of 1 is unifiable to the inner type
        // (INTEGER) == INTEGER
        case let (.row(row), t) where row.count == 1 && !t.isRow:
            unify(row.first!, with: t, at: location)
            
        case let (t, .row(row)) where row.count == 1 && !t.isRow:
            unify(row.first!, with: t, at: location)
            
        case let (.row(.unknown(ty)), .row(rhs)):
            return unify(all: rhs.types, with: ty, at: location)
            
        case let (.row(lhs), .row(.unknown(ty))):
            return unify(all: lhs.types, with: ty, at: location)
            
        case let (.row(rhs), .row(lhs)) where lhs.count == rhs.count:
            return unify(rhs.types, with: lhs.types, at: location)
            
        case let (.alias(t1, _), t2):
            return unify(t1, with: t2, at: location)
            
        case let (t1, .alias(t2, _)):
            return unify(t2, with: t1, at: location)
            
        default:
            guard type.root != other.root else { return }
            diagnostics.add(.unableToUnify(type, with: other, at: location))
        }
    }
    
    /// Unifies all types together.
    mutating func unify(
        all tys: [Type],
        at location: SourceLocation
    ) {
        var tys = tys.makeIterator()
        
        guard var lastTy = tys.next() else { return }
        
        while let ty = tys.next() {
            unify(lastTy, with: ty, at: location)
            lastTy = ty.apply(substitution)
        }
    }
    
    /// Performs unification on the two collections of types by unifying
    /// each element in the collection with the type at the same index in
    /// the other collection.
    ///
    /// This assumes that both collections are of the same size.
    private mutating func unify<T1: Collection, T2: Collection>(
        _ tys: T1,
        with others: T2,
        at location: SourceLocation
    )
        where T1.Element == Type, T2.Element == Type
    {
        assert(tys.count == others.count)
        
        var tys = tys.makeIterator()
        var others = others.makeIterator()
        
        while let ty1 = tys.next(), let ty2 = others.next() {
            unify(
                ty1.apply(substitution),
                with: ty2.apply(substitution),
                at: location
            )
        }
    }
    
    /// Unifies all types with one single type.
    private mutating func unify<T1: Collection>(
        all tys: T1,
        with ty1: Type,
        at location: SourceLocation
    )
        where T1.Element == Type
    {
        for ty2 in tys {
            unify(ty1.apply(substitution), with: ty2.apply(substitution), at: location)
        }
    }
    
    /// Makes sure the type variable can be unified with the type
    private mutating func validateCanUnify(
        type: Type,
        with tvKind: TypeVariable.Kind,
        at location: SourceLocation
    ) {
        switch type {
        case let .alias(t, _):
            return validateCanUnify(type: t, with: tvKind, at: location)
        case let .optional(t):
            return validateCanUnify(type: t, with: tvKind, at: location)
        case .var:
            return
        default:
            break
        }
        
        switch tvKind {
        case .general:
            return
        case .integer:
            switch type {
            case .int, .integer, .real: return
            case .row(let row) where row.count == 1:
                validateCanUnify(type: row.first!, with: tvKind, at: location)
            default:
                diagnostics.add(.unableToUnify(type, with: .integer, at: location))
            }
        case .float:
            switch type {
            case .int, .integer, .real: return
            case .row(let row) where row.count == 1:
                validateCanUnify(type: row.first!, with: tvKind, at: location)
            default:
                diagnostics.add(.unableToUnify(type, with: .real, at: location))
            }
        }
    }
    
    private mutating func substitute(_ tyVar: TypeVariable, for type: Type) {
        // If the ty var isnt the final leaf in the substitution map
        // it will break the linked list of substitutions.
        assert(substitution[tyVar] == nil)
        substitution[tyVar] = type
    }
}

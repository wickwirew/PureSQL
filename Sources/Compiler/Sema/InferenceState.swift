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
    /// Any ranges the bind parameters show up in.
    /// This really isnt the most sensible place for this. May likely break out into its
    /// own thing but keeping it here for now since its so simple.
    private(set) var bindIndexRanges: [BindParameterSyntax.Index: [Range<Substring.Index>]] = [:]
    
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
        bindIndexRanges[param.index, default: []].append(param.range)
        
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
            return .row(row.mapTypes { solution(for: $0, defaultIfTyVar: true) })
        default:
            return result
        }
    }
    
    /// Gets the list of parameters and their solution type.
    /// If `defaultIfTyVar` is true, the type will be given a
    /// default value if it is a type var.
    func parameterSolutions(
        defaultIfTyVar: Bool = false
    ) -> [(index: BindParameterSyntax.Index, type: Type, ranges: [Range<Substring.Index>])] {
        return bindIndexToSyntaxIds.map { (index, syntaxId) in
            let type = self.syntaxTypes[syntaxId] ?? .error
            let ranges = self.bindIndexRanges[index] ?? []
            return (index, solution(for: type, defaultIfTyVar: defaultIfTyVar), ranges)
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
        at range: Range<String.Index>
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
        case let (.optional(t1), .optional(t2)):
            unify(t1, with: t2, at: range)
        case let (.var(nonOptional), .optional(.var(optional))):
            let kind = max(nonOptional.kind, optional.kind)
            substitute(nonOptional, for: .optional(.var(optional.with(kind: kind))))
        case let (.optional(.var(optional)), .var(nonOptional)):
            let kind = max(nonOptional.kind, optional.kind)
            substitute(nonOptional, for: .optional(.var(optional.with(kind: kind))))
        case let (.var(tv), ty):
            validateCanUnify(type: ty, with: tv.kind, at: range)
            substitute(tv, for: ty)
        case let (ty, .var(tv)):
            validateCanUnify(type: ty, with: tv.kind, at: range)
            substitute(tv, for: ty)
        case (.integer, .real):
            return // Not equal but valid to use together
        case (.real, .integer):
            return // Not equal but valid to use together
        case let (.fn(args1, ret1), .fn(args2, ret2)):
            unify(args1, with: args2, at: range)
            unify(ret1.apply(substitution), with: ret2.apply(substitution), at: range)
        case let (.row(.unknown(ty)), .row(rhs)):
            return unify(all: rhs.types, with: ty, at: range)
        case let (.row(lhs), .row(.unknown(ty))):
            return unify(all: lhs.types, with: ty, at: range)
        case let (.row(rhs), .row(lhs)) where lhs.count == rhs.count:
            return unify(rhs.types, with: lhs.types, at: range)
        case let (.row(row), t):
            if row.count == 1, let first = row.first {
                unify(first, with: t, at: range)
            } else {
                diagnostics.add(.unableToUnify(type, with: other, at: range))
            }
        case let (t, .row(row)):
            if row.count == 1, let first = row.first {
                unify(first, with: t, at: range)
            } else {
                diagnostics.add(.unableToUnify(type, with: other, at: range))
            }
        case let (.alias(t1, _), t2):
            return unify(t1, with: t2, at: range)
        case let (t1, .alias(t2, _)):
            return unify(t2, with: t1, at: range)
        default:
            guard type.root != other.root else { return }
            diagnostics.add(.unableToUnify(type, with: other, at: range))
        }
    }
    
    /// Unifies all types together.
    mutating func unify(
        all tys: [Type],
        at range: Range<String.Index>
    ) {
        var tys = tys.makeIterator()
        
        guard var lastTy = tys.next() else { return }
        
        while let ty = tys.next() {
            unify(lastTy, with: ty, at: range)
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
        at range: Range<String.Index>
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
                at: range
            )
        }
    }
    
    /// Unifies all types with one single type.
    private mutating func unify<T1: Collection>(
        all tys: T1,
        with ty1: Type,
        at range: Range<String.Index>
    )
        where T1.Element == Type
    {
        for ty2 in tys {
            unify(ty1.apply(substitution), with: ty2.apply(substitution), at: range)
        }
    }
    
    /// Makes sure the type variable can be unified with the type
    private mutating func validateCanUnify(
        type: Type,
        with tvKind: TypeVariable.Kind,
        at range: Range<Substring.Index>
    ) {
        if case let .alias(t, _) = type {
            return validateCanUnify(type: t, with: tvKind, at: range)
        }
        
        if case let .optional(t) = type {
            return validateCanUnify(type: t, with: tvKind, at: range)
        }
        
        switch tvKind {
        case .general:
            return
        case .integer:
            switch type {
            case .int, .integer, .real: return
            default:
                diagnostics.add(.unableToUnify(type, with: .integer, at: range))
            }
        case .float:
            switch type {
            case .int, .integer, .real: return
            default:
                diagnostics.add(.unableToUnify(type, with: .real, at: range))
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

//
//  Grouping.swift
//  Feather
//
//  Created by Wes Wickwire on 5/10/25.
//

public protocol Association: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func group(input: Input) throws -> Output
}

public struct ManyToManyAssociation<Parent, ParentKey, Map, Child, ChildKey>: Association
    where Parent: Sendable, Child: Sendable, ParentKey: Hashable & Sendable, ChildKey: Hashable & Sendable, Map: Sendable
{
    public typealias Output = [(Parent, [Child])]
    
    let parentKey: @Sendable (Parent) -> ParentKey
    let mapParentKey: @Sendable (Map) -> ParentKey
    let childKey: @Sendable (Child) -> ChildKey
    let mapChildKey: @Sendable (Map) -> ChildKey
    
    public func group(input: ([Parent], [Map], [Child])) throws -> Output {
        let (parents, maps, children) = input
        
        var parentToChildIDs: [ParentKey: Set<ChildKey>] = [:]
        for map in maps {
            let pID = mapParentKey(map)
            let cID = mapChildKey(map)
            parentToChildIDs[pID, default: []].insert(cID)
        }
        
        let childLookup = Dictionary(uniqueKeysWithValues: children.map { (childKey($0), $0) })
        
        var output: Output = []
        output.reserveCapacity(parents.count)
        
        for parent in parents {
            let pID = parentKey(parent)
            let cIDs = parentToChildIDs[pID] ?? []
            let associatedChildren = cIDs.compactMap { childLookup[$0] }
            output.append((parent, associatedChildren))
        }
        
        return output
    }
}

public struct OptionalOneToOneAssociation<Parent, Child, ChildKey>: Association
    where ChildKey: Hashable, Parent: Sendable, Child: Sendable
{
    let childKey: @Sendable (Child) -> ChildKey
    let childKeyFromParent: @Sendable (Parent) -> ChildKey?
    
    public func group(input: ([Parent], [Child])) throws -> [(Parent, Child?)] {
        let (parents, children) = input
        
        let childrenByKey: [ChildKey: Child] = children
            .reduce(into: [:]) { $0[childKey($1)] = $1 }

        return try parents.map { parent in
            guard let childKey = childKeyFromParent(parent) else {
                return (parent, nil)
            }
            
            guard let child = childrenByKey[childKey] else {
                throw FeatherError.requiredAssociationFailed(
                    parent: "\(parent)",
                    childKey: "\(childKey)"
                )
            }
            
            return (parent, child)
        }
    }
}

public struct RequiredOneToOneAssociation<Parent, Child, ChildKey>: Association
    where ChildKey: Hashable, Parent: Sendable, Child: Sendable
{
    let childKey: @Sendable (Child) -> ChildKey
    let childKeyFromParent: @Sendable (Parent) -> ChildKey
    
    public func group(input: ([Parent], [Child])) throws -> [(Parent, Child?)] {
        let (parents, children) = input
        
        let childrenByKey: [ChildKey: Child] = children
            .reduce(into: [:]) { $0[childKey($1)] = $1 }

        return try parents.map { parent in
            let childKey = childKeyFromParent(parent)
            
            guard let child = childrenByKey[childKeyFromParent(parent)] else {
                throw FeatherError.requiredAssociationFailed(
                    parent: "\(parent)",
                    childKey: "\(childKey)"
                )
            }
            
            return (parent, child)
        }
    }
}

/// Child has reference to parent
public struct OneToManyAssociation<Parent, Child, ParentKey>: Association
    where ParentKey: Hashable, Parent: Sendable, Child: Sendable
{
    let parentKey: @Sendable (Parent) -> ParentKey
    let parentKeyFromChild: @Sendable (Child) -> ParentKey
    
    public func group(input: ([Parent], [Child])) -> [(Parent, [Child])] {
        let (parents, children) = input
        
        var childrenForParent: [ParentKey: [Child]] = [:]
        for child in children {
            childrenForParent[parentKeyFromChild(child), default: []].append(child)
        }
        
        return parents.map { parent in
            (parent, childrenForParent[parentKey(parent)] ?? [])
        }
    }
}

public struct Grouping<Base: Query, A: Association>: Query
    where Base.Output == A.Input
{
    public typealias Output = A.Output
    
    let base: Base
    let association: A
    
    public func execute(
        with input: Base.Input
    ) async throws -> Output {
        return try await association.group(input: base.execute(with: input))
    }
    
    public func observe(
        with input: Base.Input
    ) -> any QueryObservation<Output> {
        fatalError()
    }
}

extension Grouping: DatabaseQuery where Base: DatabaseQuery {
    public var transactionKind: Transaction.Kind {
        return base.transactionKind
    }
    
    public var connection: any Connection {
        return base.connection
    }
    
    public var watchedTables: Set<String> {
        return base.watchedTables
    }
    
    public func execute(
        with input: Base.Input,
        tx: borrowing Transaction
    ) throws -> A.Output {
        return try association.group(input: base.execute(with: input, tx: tx))
    }
}

extension Query {
    /// Given an array of parents and array of children it will group
    /// them together via a "one to one" relationship through the referenced
    /// child id on the parent to the child.
    ///
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name | capitalId`
    /// `city`: `id | name `
    ///
    /// If we wanted to fetch all states with their capital city we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities that are a captial by passing the list of captial ids to it
    /// with a `SELECT * FROM city WHERE id IN ?`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    ///
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities) { _, states in states.map(\.capitalId) }
    ///     .grouping(one: \.capitalId, toOne: \.id)
    /// ```
    ///
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameters:
    ///   - childKeyFromParent: The property that is the child `id` on the parent record.
    /// - Returns: A query that returns the parent associated to it's single child
    public func grouping<Parent, Child>(
        oneToOneThrough childKeyFromParent: @escaping @Sendable (Parent) -> Child.ID
    ) -> Grouping<Self, RequiredOneToOneAssociation<Parent, Child, Child.ID>>
        where Output == ([Parent], [Child]), Child: Identifiable
    {
        let association = RequiredOneToOneAssociation<Parent, Child, Child.ID>(
            childKey: { $0.id },
            childKeyFromParent: childKeyFromParent
        )
        return Grouping(base: self, association: association)
    }
    
    
    /// Given an array of parents and array of children it will group
    /// them together via a "one to one" relationship through the referenced
    /// child id on the parent to the child.
    ///
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name | capitalId`
    /// `city`: `id | name `
    ///
    /// If we wanted to fetch all states with their capital city we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities that are a captial by passing the list of captial ids to it
    /// with a `SELECT * FROM city WHERE id IN ?`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    ///
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities) { _, states in states.map(\.capitalId) }
    ///     .grouping(one: \.capitalId, toOne: \.id)
    /// ```
    ///
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameters:
    ///   - childKeyFromParent: The property to use as the reference from the parent
    ///   table to the child table
    ///   - childKey: The property to use as the key of the child table that would
    ///   match the key returned by `childKeyFromParent`.
    /// - Returns: A query that returns the parent associated to it's single child
    public func grouping<Parent, Child, ChildKey>(
        one childKeyFromParent: @escaping @Sendable (Parent) -> ChildKey,
        toOne childKey: @escaping @Sendable (Child) -> ChildKey
    ) -> Grouping<Self, RequiredOneToOneAssociation<Parent, Child, ChildKey>>
        where Output == ([Parent], [Child])
    {
        let association = RequiredOneToOneAssociation(
            childKey: childKey,
            childKeyFromParent: childKeyFromParent
        )
        return Grouping(base: self, association: association)
    }
    
    /// Given an array of parents and array of children it will group
    /// them together via a "one to one" relationship through the referenced
    /// child id on the parent to the child.
    ///
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name | capitalId`
    /// `city`: `id | name `
    ///
    /// If we wanted to fetch all states with their capital city we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities that are a captial by passing the list of captial ids to it
    /// with a `SELECT * FROM city WHERE id IN ?`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    ///
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities) { _, states in states.map(\.capitalId) }
    ///     .grouping(one: \.capitalId, toOne: \.id)
    /// ```
    ///
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameters:
    ///   - childKeyFromParent: The property that is the child `id` on the parent record.
    /// - Returns: A query that returns the parent associated to it's single child
    public func grouping<Parent, Child>(
        oneToOneThrough childKeyFromParent: @escaping @Sendable (Parent) -> Child.ID?
    ) -> Grouping<Self, OptionalOneToOneAssociation<Parent, Child, Child.ID>>
        where Output == ([Parent], [Child]), Child: Identifiable
    {
        let association = OptionalOneToOneAssociation<Parent, Child, Child.ID>(
            childKey: { $0.id },
            childKeyFromParent: childKeyFromParent
        )
        return Grouping(base: self, association: association)
    }
    
    
    /// Given an array of parents and array of children it will group
    /// them together via a "one to one" relationship through the referenced
    /// child id on the parent to the child.
    /// 
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name | capitalId`
    /// `city`: `id | name `
    /// 
    /// If we wanted to fetch all states with their capital city we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities that are a captial by passing the list of captial ids to it
    /// with a `SELECT * FROM city WHERE id IN ?`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    /// 
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities) { _, states in states.map(\.capitalId) }
    ///     .grouping(one: \.capitalId, toOne: \.id)
    /// ```
    /// 
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameters:
    ///   - childKeyFromParent: The property to use as the reference from the parent
    ///   table to the child table
    ///   - childKey: The property to use as the key of the child table that would
    ///   match the key returned by `childKeyFromParent`.
    /// - Returns: A query that returns the parent associated to it's single child
    public func grouping<Parent, Child, ChildKey>(
        one childKeyFromParent: @escaping @Sendable (Parent) -> ChildKey?,
        toOne childKey: @escaping @Sendable (Child) -> ChildKey
    ) -> Grouping<Self, OptionalOneToOneAssociation<Parent, Child, ChildKey>>
        where Output == ([Parent], [Child])
    {
        let association = OptionalOneToOneAssociation(
            childKey: childKey,
            childKeyFromParent: childKeyFromParent
        )
        return Grouping(base: self, association: association)
    }
    
    /// Given an array of parents and array of children it will group
    /// them together via a "one to many" relationship through the referenced
    /// parent id on the child to the parent.
    /// 
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name`
    /// `city`: `id | name | stateId`
    /// 
    /// If we wanted to fetch all states with their cities we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities with a `SELECT * FROM city`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    /// 
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities)
    ///     .grouping(oneToManyThrough: \.stateId)
    /// ```
    /// 
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameter parentId: The ID of the parent record from the child record
    /// - Returns: A query that returns the parent associated to its child
    public func grouping<Parent, Child>(
        oneToManyThrough parentId: @escaping @Sendable (Child) -> Parent.ID
    ) -> Grouping<Self, OneToManyAssociation<Parent, Child, Parent.ID>>
        where Output == ([Parent], [Child]), Parent: Identifiable
    {
        let association = OneToManyAssociation<Parent, Child, Parent.ID>(
            parentKey: { $0.id },
            parentKeyFromChild: parentId
        )
        return Grouping(base: self, association: association)
    }
    
    /// Given an array of parents and array of children it will group
    /// them together via a "one to many" relationship through the referenced
    /// parent key on the child to the parent.
    /// 
    /// Example:
    /// If we have two tables `state` and `city`.
    /// `state`: `id | name`
    /// `city`: `id | name | stateId`
    /// 
    /// If we wanted to fetch all states with their cities we could select
    /// all of the states using a simple `SELECT * FROM state` and then select
    /// all cities with a `SELECT * FROM city`. Using the `then` operator
    /// that would give us an output of `([State], [City])`. Using the
    /// `groupingBy(childId:)` operator we can associate the two in memory
    /// to be `[(State, [City])]`.
    /// 
    /// Example:
    /// ```swift
    /// selectAllStates
    ///     .then(selectAllCities)
    ///     .grouping(one: \.id, toManyThrough: \.stateId)
    /// ```
    /// 
    /// Using this operator you can limit the calls to the database. Fetching
    /// all records up front and associating them in memory.
    ///
    /// - Parameters:
    ///   - parentKey: The key to use for the parent
    ///   - parentKeyFromChild: The key of the parent on the child record
    /// - Returns: A query that returns the parent with all child records
    public func grouping<Parent, Child, ParentKey>(
        one parentKey: @escaping @Sendable (Parent) -> ParentKey,
        toManyThrough parentKeyFromChild: @escaping @Sendable (Child) -> ParentKey
    ) -> Grouping<Self, OneToManyAssociation<Parent, Child, ParentKey>>
        where Output == ([Parent], [Child])
    {
        let association = OneToManyAssociation(
            parentKey: parentKey,
            parentKeyFromChild: parentKeyFromChild
        )
        return Grouping(base: self, association: association)
    }
    
    public func groupingManyToMany<Parent, Map, Child>(
        through parentId: @escaping @Sendable (Map) -> Parent.ID,
        and childId: @escaping @Sendable (Map) -> Child.ID
    ) -> Grouping<Self, ManyToManyAssociation<Parent, Parent.ID, Map, Child, Child.ID>>
        where Parent: Identifiable, Child: Identifiable
    {
        return groupingManyToMany(
            many: \.id,
            toMany: \.id,
            through: parentId,
            and: childId
        )
    }
    
    public func groupingManyToMany<Parent, ParentKey, Map, Child, ChildKey>(
        many parentKey: @escaping @Sendable (Parent) -> ParentKey,
        toMany childKey: @escaping @Sendable (Child) -> ChildKey,
        through mapParentKey: @escaping @Sendable (Map) -> ParentKey,
        and mapChildKey: @escaping @Sendable (Map) -> ChildKey
    ) -> Grouping<Self, ManyToManyAssociation<Parent, ParentKey, Map, Child, ChildKey>> {
        let association = ManyToManyAssociation(
            parentKey: parentKey,
            mapParentKey: mapParentKey,
            childKey: childKey,
            mapChildKey: mapChildKey
        )
        return Grouping(base: self, association: association)
    }
}

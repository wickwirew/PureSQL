//
//  DuplicateDictionary.swift
//  PureSQL
//
//  Created by Wes Wickwire on 5/31/25.
//

/// A dictionary that retains order and allows duplicates but
/// still has fast O(1) lookups.
///
/// SQLite columns and scopes have some capabilities that don't really
/// fit any data structure currently available. When we insert into the
/// environment we need to retain order. This rules out `Dictionary`.
///
/// Columns with duplicate names can exist as well.
/// This rules out `OrderedDictionary`.
///
/// For simplification it is append only.
public struct DuplicateDictionary<Key: Hashable, Value> {
    /// All elements of the dictionary appended in order
    @usableFromInline
    var _values: ContiguousArray<_Element>
    /// A dictionary where each value is located.
    @usableFromInline
    var positions: [Key: Positions]
    
    public typealias Index = Int
    public typealias Element = (key: Key, value: Value)
    
    /// Tuples cannot be equatable...
    public struct _Element {
        @usableFromInline var key: Key
        @usableFromInline var value: Value
        
        @usableFromInline
        @inline(__always)
        var tuple: (Key, Value) {
            return (key, value)
        }
        
        init(_ key: Key, _ value: Value) {
            self.key = key
            self.value = value
        }
    }
    
    /// Result value from a key lookup.
    public struct Entries {
        @usableFromInline
        let positions: Positions
        @usableFromInline
        let owner: DuplicateDictionary
        
        @inline(__always)
        @inlinable
        init(
            positions: Positions,
            owner: DuplicateDictionary
        ) {
            self.positions = positions
            self.owner = owner
        }
        
        var values: [Value] {
            return self.map(\.self)
        }
        
        var first: Value? {
            return switch positions {
            case .empty: nil
            case let .single(i): owner._values[i].value
            case let .many(i): i.first.map { owner._values[$0].value }
            }
        }
    }
    
    /// Where the element is location in the `values` array.
    public enum Positions: Sendable, Equatable, Sequence {
        public typealias Index = Int
        public typealias Element = Int
        
        /// Nowhere
        case empty
        /// Just a single location
        case single(Int)
        /// In many spots
        case many([Int])
        
        /// How many spots it exists
        @inline(__always)
        @inlinable
        var count: Int {
            return switch self {
            case .empty: 0
            case .single: 1
            case let .many(i): i.count
            }
        }
        
        /// Adds the index to the positions
        @inline(__always)
        mutating func adding(_ index: Int) {
            switch self {
            case .empty:
                self = .single(index)
            case let .single(existing):
                self = .many([existing, index])
            case var .many(existing):
                existing.append(index)
                self = .many(existing)
            }
        }
        
        public func makeIterator() -> Iterator {
            Iterator(positions: self)
        }
        
        public struct Iterator: IteratorProtocol {
            let positions: Positions
            var currentIndex = 0
            
            public mutating func next() -> Element? {
                defer { currentIndex += 1 }
                switch positions {
                case .empty:
                    return nil
                case let .single(index):
                    return currentIndex == 0 ? index : nil
                case let .many(indices):
                    guard currentIndex < indices.count else { return nil }
                    return indices[currentIndex]
                }
            }
        }
    }

    public init() {
        self._values = []
        self.positions = [:]
    }
    
    private init(
        values: ContiguousArray<_Element>,
        positions: [Key : Positions]
    ) {
        self._values = values
        self.positions = positions
    }
    
    public init<S: Sequence>(
        _ sequence: S
    ) where S.Element == Element {
        self = .init()
        
        for (k, v) in sequence {
            append(v, for: k)
        }
    }
    
    /// Appends the value for the given key
    @inline(__always)
    public mutating func append(_ value: Value, for key: Key) {
        let index = _values.count
        _values.append(_Element(key, value))
        positions[key, default: .empty].adding(index)
    }
    
    @inline(__always)
    @inlinable
    public mutating func append<S: Sequence>(
        contentsOf collection: S
    ) where S.Element == Element {
        for (key, value) in collection {
            append(value, for: key)
        }
    }
    
    /// Gets the values for the given key
    @inline(__always)
    @inlinable
    public subscript(key: Key) -> Entries {
        guard let positions = positions[key] else {
            return Entries(positions: .empty, owner: self)
        }
        
        return Entries(positions: positions, owner: self)
    }
    
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        _values.reserveCapacity(minimumCapacity)
        positions.reserveCapacity(minimumCapacity)
    }
    
    public func contains(key: Key) -> Bool {
        guard let p = positions[key] else { return false }
        return p != .empty
    }
    
    /// Renames all values under the `key` to the `newKey`
    public mutating func rename(_ key: Key, to newKey: Key) {
        guard let positions = positions[key] else { return }
        
        for index in positions {
            _values[index].key = newKey
        }
        
        // Insert positions for new key and remove old one.
        self.positions[newKey] = positions
        self.positions[key] = nil
    }
    
    /// Updates all values for the given `key` to be the `newValue`
    public mutating func updateAll(_ key: Key, to newValue: Value) {
        guard let positions = positions[key] else { return }
        
        for index in positions {
            _values[index].value = newValue
        }
    }
    
    /// Map over the values and transform them into a new dictionary
    /// with the same keys but with the transformed values.
    public func mapValues<T>(
        _ transform: (Value) throws -> T
    ) rethrows -> DuplicateDictionary<Key, T> {
        return try DuplicateDictionary<Key, T>(
            values: ContiguousArray(_values.map {
                try DuplicateDictionary<Key, T>._Element($0.key, transform($0.value))
            }),
            positions: positions.reduce(into: [:]) { r, p in
                r[p.key] = switch p.value {
                case .empty: .empty
                case let .single(i): .single(i)
                case let .many(i): .many(i)
                }
            }
        )
    }
}

extension DuplicateDictionary: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (Key, Value)...) {
        self = DuplicateDictionary()
        self.reserveCapacity(elements.count)
        
        for (key, value) in elements {
            append(value, for: key)
        }
    }
}

extension DuplicateDictionary: Collection {
    public var startIndex: Index { return _values.startIndex }
    public var endIndex: Index { return _values.endIndex }
    
    @inline(__always)
    @inlinable
    public subscript(index: Index) -> Element { _values[index].tuple }
    
    @inline(__always)
    @inlinable
    public var count: Int { _values.count }
    
    @inline(__always)
    @inlinable
    public var first: Element? { _values.first?.tuple }
    
    @inline(__always)
    @inlinable
    public var last: Element? { _values.last?.tuple }
    
    @inline(__always)
    @inlinable
    public func index(after i: Index) -> Index {
        _values.index(after: i)
    }
    
    public func makeIterator() -> Iterator {
        Iterator(dictionary: self)
    }
    
    public struct Iterator: IteratorProtocol {
        let dictionary: DuplicateDictionary
        var index = 0
        
        public mutating func next() -> Element? {
            guard index < dictionary.count else { return nil }
            defer { index += 1 }
            return dictionary._values[index].tuple
        }
    }
}

extension DuplicateDictionary.Entries: Collection {
    public typealias Element = Value
    public typealias Index = Int

    @inline(__always)
    @inlinable
    public subscript(index: Index) -> Element {
        switch positions {
        case .empty:
            preconditionFailure("Index out of bounds")
        case let .single(i):
            guard index == 0 else { preconditionFailure("Index out of bounds") }
            return owner._values[i].value
        case let .many(i):
            return owner._values[i[index]].value
        }
    }
    
    @inline(__always)
    @inlinable
    public var count: Int { positions.count }
    
    @inline(__always)
    @inlinable
    public var startIndex: Int { 0 }
    
    @inline(__always)
    @inlinable
    public var endIndex: Int { positions.count }
    
    @inline(__always)
    @inlinable
    public func index(after i: Index) -> Index { i + 1 }
}

public extension DuplicateDictionary {
    /// All values in the dictionary without their key.
    var values: Values {
        Values(dictionary: self)
    }
    
    struct Values: Collection {
        public typealias Element = Value
        
        @usableFromInline
        let dictionary: DuplicateDictionary
        
        init(dictionary: DuplicateDictionary) {
            self.dictionary = dictionary
        }
        
        @inline(__always)
        @inlinable
        public subscript(index: Index) -> Element { dictionary._values[index].value }
        
        @inline(__always)
        @inlinable
        public var count: Int { dictionary._values.count }
        
        @inline(__always)
        @inlinable
        public var startIndex: Int { dictionary._values.startIndex }
        
        @inline(__always)
        @inlinable
        public var endIndex: Int { dictionary._values.endIndex }
        
        @inline(__always)
        @inlinable
        public func index(after i: Index) -> Index {
            dictionary._values.index(after: i)
        }
    }
}

extension DuplicateDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension DuplicateDictionary._Element: Sendable where Key: Sendable, Value: Sendable {}
extension DuplicateDictionary._Element: Equatable where Key: Equatable, Value: Equatable {}
extension DuplicateDictionary: Equatable where Key: Equatable, Value: Equatable {}

extension DuplicateDictionary: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(self, unlabeledChildren: self.map(\.self), displayStyle: .dictionary)
    }
}

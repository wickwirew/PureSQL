//
//  DuplicateDictionary.swift
//  Feather
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
    internal var _values: ContiguousArray<_Element>
    /// A dictionary where each value is located.
    @usableFromInline
    internal var positions: [Key: DuplicateDictionaryPositions]
    
    public typealias Index = Int
    public typealias Element = (key: Key, value: Value)
    
    /// Tuples cannot be equatable...
    public struct _Element {
        @usableFromInline let key: Key
        @usableFromInline let value: Value
        
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
        private let positions: DuplicateDictionaryPositions
        private let owner: DuplicateDictionary
        
        @inline(__always)
        fileprivate init(
            positions: DuplicateDictionaryPositions,
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
            case .single(let i): owner._values[i].value
            case .many(let i): i.first.map { owner._values[$0].value }
            }
        }
    }
    
    public init() {
        self._values = []
        self.positions = [:]
    }
    
    private init(
        values: ContiguousArray<_Element>,
        positions: [Key : DuplicateDictionaryPositions]
    ) {
        self._values = values
        self.positions = positions
    }
    
    /// Appends the value for the given key
    @inline(__always)
    public mutating func append(_ value: Value, for key: Key) {
        let index = _values.count
        _values.append(_Element(key, value))
        positions[key, default: .empty].adding(index)
    }
    
    /// Gets the values for the given key
    @inline(__always)
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
    
    /// Map over the values and transform them into a new dictionary
    /// with the same keys but with the transformed values.
    public func mapValues<T>(
        _ transform: (Value) throws -> T
    ) rethrows -> DuplicateDictionary<Key, T> {
        return try DuplicateDictionary<Key, T>(
            values: ContiguousArray(_values.map{
                DuplicateDictionary<Key, T>._Element($0.key, try transform($0.value))
            }),
            positions: positions
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

extension DuplicateDictionary.Entries: Sequence {
    public typealias Element = Value

    @inline(__always)
    public var count: Int { positions.count }
    
    @inline(__always)
    public func makeIterator() -> Iterator {
        Iterator(element: self)
    }
    
    public struct Iterator: IteratorProtocol {
        private let element: DuplicateDictionary.Entries
        private var currentIndex = 0
        
        init(element: DuplicateDictionary.Entries) {
            self.element = element
        }
        
        @inline(__always)
        public mutating func next() -> Value? {
            defer { currentIndex += 1 }
            
            switch element.positions {
            case .empty:
                return nil
            case .single(let index):
                return currentIndex == 0 ? element.owner._values[index].value : nil
            case .many(let indices):
                guard currentIndex < indices.count else { return nil }
                return element.owner._values[currentIndex].value
            }
        }
    }
}

extension DuplicateDictionary {
    /// All values in the dictionary without their key.
    public var values: Values {
        Values(dictionary: self)
    }
    
    public struct Values: Sequence {
        public typealias Element = Value
        
        let dictionary: DuplicateDictionary
        
        init(dictionary: DuplicateDictionary) {
            self.dictionary = dictionary
        }
        
        public func makeIterator() -> Iterator {
            return Iterator(dictionary: dictionary)
        }
        
        public struct Iterator: IteratorProtocol {
            private let dictionary: DuplicateDictionary
            private var index = 0
            
            @usableFromInline
            init(dictionary: DuplicateDictionary) {
                self.dictionary = dictionary
            }
            
            public mutating func next() -> Element? {
                guard index < dictionary._values.count else { return nil }
                defer { index += 1 }
                return dictionary._values[index].value
            }
        }
    }
}

extension DuplicateDictionary: Sendable where Key: Sendable, Value: Sendable {}
extension DuplicateDictionary._Element: Sendable where Key: Sendable, Value: Sendable {}
extension DuplicateDictionary._Element: Equatable where Key: Equatable, Value: Equatable {}
extension DuplicateDictionary: Equatable where Key: Equatable, Value: Equatable {}

/// Where the element is location in the `values` array.
///
/// This cannot be nested in the `DuplicateDictionary` struct
/// due to the `mapValues` since `DuplicateDictionary<T, V>.Positions`
/// is not equal too `DuplicateDictionary<T, NewValue>.Positions`
public enum DuplicateDictionaryPositions: Sendable, Equatable, Sequence {
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
    var count: Int {
        return switch self {
        case .empty: 0
        case .single: 1
        case .many(let i): i.count
        }
    }
    
    /// Adds the index to the positions
    @inline(__always)
    mutating func adding(_ index: Int) {
        switch self {
        case .empty:
            self = .single(index)
        case .single(let existing):
            self = .many([existing, index])
        case .many(var existing):
            existing.append(index)
            self = .many(existing)
        }
    }
    
    public func makeIterator() -> Iterator {
        Iterator(positions: self)
    }
    
    public struct Iterator: IteratorProtocol {
        let positions: DuplicateDictionaryPositions
        var currentIndex = 0
        
        public mutating func next() -> Element? {
            switch positions {
            case .empty:
                return nil
            case .single(let index):
                return currentIndex == 0 ? index : nil
            case .many(let indices):
                guard currentIndex < indices.count else { return nil }
                return indices[currentIndex]
            }
        }
    }
}

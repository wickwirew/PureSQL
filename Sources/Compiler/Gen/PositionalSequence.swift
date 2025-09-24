//
//  PositionalSequence.swift
//  PureSQL
//
//  Created by Wes Wickwire on 4/29/25.
//

struct PositionalSequence<Base: Collection>: Sequence {
    typealias Element = (Position, Base.Element)
    
    let base: Base
    
    struct Position: OptionSet {
        let rawValue: UInt8
        
        static var first: Position { Position(rawValue: 1 << 0) }
        static var last: Position { Position(rawValue: 1 << 1) }
        
        var isFirst: Bool { contains(.first) }
        var isLast: Bool { contains(.last) }
    }
    
    func makeIterator() -> Iterator {
        Iterator(
            base: base.enumerated().makeIterator(),
            count: base.count
        )
    }
    
    struct Iterator: IteratorProtocol {
        var base: EnumeratedSequence<Base>.Iterator
        let count: Int
        
        mutating func next() -> Element? {
            guard let (offset, element) = base.next() else { return nil }
            var position: Position = []
            
            if offset == 0 {
                position.insert(.first)
            }
            
            if offset == count - 1 {
                position.insert(.last)
            }
            
            return (position, element)
        }
    }
}

extension Collection {
    func positional() -> PositionalSequence<Self> {
        return PositionalSequence(base: self)
    }
}

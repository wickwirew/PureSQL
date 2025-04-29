//
//  PositionalSequence.swift
//  Feather
//
//  Created by Wes Wickwire on 4/29/25.
//

struct PositionalSequence<Base: Collection>: Sequence {
    typealias Element = (Position?, Base.Element)
    
    let base: Base
    
    enum Position {
        case first
        case last
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
            
            if offset == 0 {
                return (.first, element)
            } else if offset == count - 1 {
                return (.last, element)
            } else {
                return (nil, element)
            }
        }
    }
}

extension Collection {
    func positional() -> PositionalSequence<Self> {
        return PositionalSequence(base: self)
    }
}

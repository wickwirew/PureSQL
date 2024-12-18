//
//  Names.swift
//  Feather
//
//  Created by Wes Wickwire on 12/17/24.
//


/// Manages the inference for the unnamed bind parameters.
struct Names {
    /// The last expressions possible name.
    let last: Name
    /// A map of all params names. Including explicit and inferred
    let map: [Int: Substring]
    
    enum Name {
        case needed(index: Int)
        case some(Substring)
        case none
    }
    
    static let none = Names(last: .none, map: [:])
    
    static func some(_ value: Substring) -> Names {
        return Names(last: .some(value), map: [:])
    }
    
    static func needed(index: Int) -> Names {
        return Names(last: .needed(index: index), map: [:])
    }
    
    static func defined(_ name: Substring, for index: Int) -> Names {
        return Names(last: .none, map: [index: name])
    }
    
    var lastName: Substring? {
        if case let .some(s) = last { return s }
        return nil
    }
    
    func merging(_ other: Names) -> Names {
        switch (last, other.last) {
        case let (.needed(index), .some(name)):
            var map = map
            map[index] = name
            return Names(last: .none, map: map.merging(other.map, uniquingKeysWith: { $1 }))
        case let (.some(name), .needed(index)):
            var map = map
            map[index] = name
            return Names(last: .none, map: map.merging(other.map, uniquingKeysWith: { $1 }))
        case (.none, _):
            return Names(last: other.last, map: map.merging(other.map, uniquingKeysWith: { $1 }))
        case (_, .none):
            return Names(last: last, map: map.merging(other.map, uniquingKeysWith: { $1 }))
        default:
            return Names(last: last, map: map.merging(other.map, uniquingKeysWith: { $1 }))
        }
    }
}

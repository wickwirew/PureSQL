//
//  Indirect.swift
//  Feather
//
//  Created by Wes Wickwire on 1/13/25.
//

@dynamicMemberLookup
final class Indirect<Wrapped> {
    var value: Wrapped

    init(_ value: Wrapped) {
        self.value = value
    }

    subscript<T>(dynamicMember keyPath: KeyPath<Wrapped, T>) -> T {
        return value[keyPath: keyPath]
    }
}

extension Indirect: Equatable where Wrapped: Equatable {
    static func == (lhs: Indirect<Wrapped>, rhs: Indirect<Wrapped>) -> Bool {
        lhs.value == rhs.value
    }
}

extension Indirect: CustomStringConvertible {
    var description: String {
        return "\(value)"
    }
}

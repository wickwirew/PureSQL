//
//  Indirect.swift
//  PureSQL
//
//  Created by Wes Wickwire on 1/13/25.
//

@dynamicMemberLookup
@propertyWrapper
final class Indirect<Wrapped> {
    var wrappedValue: Wrapped

    init(_ wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }

    init(wrappedValue: Wrapped) {
        self.wrappedValue = wrappedValue
    }

    var value: Wrapped {
        self.wrappedValue
    }

    subscript<T>(dynamicMember keyPath: KeyPath<Wrapped, T>) -> T {
        return value[keyPath: keyPath]
    }
}

extension Indirect: CustomReflectable {
    var customMirror: Mirror {
        Mirror(reflecting: wrappedValue)
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

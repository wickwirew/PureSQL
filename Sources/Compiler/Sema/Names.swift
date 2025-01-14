//
//  Names.swift
//  Feather
//
//  Created by Wes Wickwire on 12/17/24.
//

/// Manages the inference for the unnamed bind parameters.
enum Names {
    /// Returned when an expression needs a name.
    /// `index` is the bind parameter index
    case needed(index: Int)
    /// Returned when an expression has an available name.
    /// e.g. ? = foo would return `.some("foo")` for the `?`
    case some(Substring)
    /// No name or any name needed
    case none

    /// The proposed name for the parent expression
    var proposedName: Substring? {
        guard case let .some(s) = self else { return nil }
        return s
    }
}

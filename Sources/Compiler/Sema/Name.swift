//
//  Names.swift
//  Feather
//
//  Created by Wes Wickwire on 12/17/24.
//

/// Represents the state of name for an expression.
enum Name: Equatable {
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
    
    /// Whether or not there is a string for a name
    var isSome: Bool {
        guard case .some = self else { return false }
        return false
    }
    
    /// Whether or a name is needed
    var isNeeds: Bool {
        guard case .needed = self else { return false }
        return false
    }
    
    static let vowels: Set<Character> = [
        "A", "E", "I", "O", "U",
        "a", "e", "i", "o", "u"
    ]
    
    /// Appends the postfix to the name if it is `some`
    func append(_ postfix: @autoclosure () -> String) -> Name {
        return switch self {
        case .some(let name): .some("\(name)\(postfix())")
        case .needed, .none: self
        }
    }
    
    /// Returns a plural version of the Name if it is `some`
    func pluralize() -> Name {
        switch self {
        case .some(var name):
            // Note: This is pretty primitive and will likely need
            // expanding on as usage grows and this spits out some
            // odd pluralizations.
            //
            // Example: "Person" would be "Persons" in this currently.
            
            let pluralName: String
            if name.last == "y" {
                name.removeLast()
                
                // Only append `ies` id the second to last char
                // in the original string is a consonant
                if let last = name.last, !Self.vowels.contains(last)  {
                    pluralName = "\(name)ies"
                } else {
                    return self
                }
            } else if name.last == "s" {
                return self
            } else {
                pluralName = "\(name)s"
            }
            return .some(pluralName[...])
        case .needed, .none:
            return self
        }
    }
}

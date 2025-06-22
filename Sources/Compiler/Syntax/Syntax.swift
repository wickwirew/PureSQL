//
//  Syntax.swift
//  Otter
//
//  Created by Wes Wickwire on 11/12/24.
//

struct SyntaxId: Hashable, Sendable {
    private let rawValue: Int

    init(_ rawValue: Int) {
        self.rawValue = rawValue
    }
}

protocol Syntax {
    var id: SyntaxId { get }
    var location: SourceLocation { get }
}

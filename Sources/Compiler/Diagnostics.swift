//
//  Diagnostics.swift
//
//
//  Created by Wes Wickwire on 10/21/24.
//

/// A list of diagnostics emitted during compilation
public struct Diagnostics {
    public private(set) var elements: [Diagnostic] = []
    
    public init(diagnostics: [Diagnostic] = []) {
        self.elements = diagnostics
    }
    
    public var isEmpty: Bool {
        return elements.isEmpty
    }
    
    @discardableResult
    public mutating func add(_ diagnostic: Diagnostic) -> Diagnostic {
        elements.append(diagnostic)
        return diagnostic
    }
    
    public mutating func merge(_ diagnostics: Diagnostics) {
        self.elements.append(contentsOf: diagnostics.elements)
    }
    
    public mutating func removeAll(keepingCapacity: Bool = false) {
        elements.removeAll(keepingCapacity: keepingCapacity)
    }
    
    public func merging(_ diagnostics: Diagnostics) -> Diagnostics {
        var copy = self
        copy.merge(diagnostics)
        return copy
    }
    
    public mutating func throwing(_ diagnostic: Diagnostic) throws {
        elements.append(diagnostic)
        throw diagnostic
    }
    
    public mutating func trying<Output>(
        _ action: () throws -> Output,
        at location: SourceLocation
    ) -> Output? {
        do {
            return try action()
        } catch {
            add(.init("\(error)", at: location))
            return nil
        }
    }
}

extension Diagnostics: Sequence {
    public func makeIterator() -> some IteratorProtocol {
        return elements.makeIterator()
    }
}

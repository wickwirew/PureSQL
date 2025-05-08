//
//  SQL.swift
//  Feather
//
//  Created by Wes Wickwire on 2/19/25.
//

public struct SQL: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
    let source: String
    let parameters: [DatabasePrimitive]
    
    public struct StringInterpolation: StringInterpolationProtocol {
        var output = ""
        var parameters: [DatabasePrimitive] = []

        public init(literalCapacity: Int, interpolationCount: Int) {
            output.reserveCapacity(literalCapacity)
        }

        public mutating func appendLiteral(_ literal: String) {
            output.append(literal)
        }
        
        public mutating func appendInterpolation<T: DatabasePrimitive>(_ primitive: T) {
            output.append("?")
            parameters.append(primitive)
        }
        
        public mutating func appendInterpolation<T: DatabasePrimitive>(_ primitives: [T]) {
            output.append("(\(primitives.map { _ in "?" }.joined(separator: ",")))")
            parameters.append(contentsOf: primitives)
        }
        
        public mutating func appendInterpolation<T>(raw: T) {
            output.append("\(raw)")
        }
    }

    public init(stringLiteral value: String) {
        source = value
        parameters = []
    }

    public init(stringInterpolation: StringInterpolation) {
        source = stringInterpolation.output
        parameters = stringInterpolation.parameters
    }
    
    public var description: String {
        return source
    }
}

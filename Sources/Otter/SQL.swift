//
//  SQL.swift
//  Otter
//
//  Created by Wes Wickwire on 2/19/25.
//

/// A type representing a SQL query with safe string interpolation.
///
/// `SQL` allows you to build SQL queries using string literals and string
/// interpolation while ensuring that any interpolated parameters are safely
/// sanitized. Interpolated values are replaced with `?` placeholders, and the
/// actual values are stored in `parameters` for binding to the database.
///
/// Example:
/// ```swift
/// let userId: Int = 42
/// let sql: SQL = "SELECT * FROM users WHERE id = \(userId)"
/// print(sql.source)       // "SELECT * FROM users WHERE id = ?"
/// print(sql.parameters)   // [42]
///
/// let ids: [Int] = [1, 2, 3]
/// let sqlIn: SQL = "SELECT * FROM users WHERE id IN \(ids)"
/// print(sqlIn.source)      // "SELECT * FROM users WHERE id IN (?,?,?)"
/// print(sqlIn.parameters)  // [1, 2, 3]
/// ```
///
/// - Note: Use `raw:` interpolation to insert values directly without a
///   parameter placeholder, which should only be done with trusted input.
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

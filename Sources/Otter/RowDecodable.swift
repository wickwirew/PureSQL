//
//  RowDecodable.swift
//  Otter
//
//  Created by Wes Wickwire on 2/16/25.
//

public protocol RowDecodable {
    static var nonOptionalIndices: [Int32] { get }
    init(row: borrowing Row, startingAt start: Int32) throws(OtterError)
}

extension RowDecodable {
    public static var nonOptionalIndices: [Int32] { [] }
    
    /// Whether or not the row has values for the required columns
    /// to successfully decode this structure.
    ///
    /// Structs generated for a table can be embedded in the output
    /// of queries using the `foo.*` syntax. This creates a unique issue
    /// where we need to know whether the row has the values for the
    /// table. If we ask SQLite for an `Int` for a null column it will
    /// just give us back a `0`. So we need to check all of the non-optional
    /// columns first to see if they have a value. If so we can safely
    /// assume the row has the table's values.
    ///
    ///
    /// Example of embedding:
    /// ```swift
    /// struct QueryOutput {
    ///     let foo: Foo
    ///     let value: Int
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - row: The row we are decoding
    ///   - start: The offset into the rows columns to start looking
    /// - Returns: `true` if all non optional columns have values.
    @inlinable
    public static func hasRequiredColumns(
        row: borrowing Row,
        startingAt start: Int32
    ) -> Bool {
        for index in nonOptionalIndices {
            if !row.hasValue(at: start + index) {
                // Doesn't have a value. No need to check rest.
                return false
            }
        }
        
        // Made it through all columns, all required exist
        return true
    }
    
    
    /// Initializes the table structure that is embedded at the given start index.
    /// Will return `nil` if it is unable to due to missing required columns
    ///
    /// - Parameters:
    ///   - row: The row the table is embedded in.
    ///   - start: The index of the first column
    public init?(row: borrowing Row, optionallyAt start: Int32) throws(OtterError) {
        guard Self.hasRequiredColumns(row: row, startingAt: start) else { return nil }
        self = try Self(row: row, startingAt: start)
    }
}


extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public static var nonOptionalIndices: [Int32] { Wrapped.nonOptionalIndices }
    
    public init(row: borrowing Row, startingAt start: Int32) throws(OtterError) {
        self = try row.value(at: start)
    }
}

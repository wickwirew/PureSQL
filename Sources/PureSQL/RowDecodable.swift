//
//  RowDecodable.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/16/25.
//

/// A type that can be decoded from a SQLite row
public protocol RowDecodable {
    /// The indices of columns that are expected to never be nil.
    static var nonOptionalIndices: [Int32] { get }
    
    /// Initializes an instance from the given row, starting at a column index.
    ///
    /// - Parameters:
    ///   - row: The SQLite row to decode values from.
    ///   - start: The starting column index in the row.
    /// - Throws: `SQLError` if decoding fails
    init(row: borrowing Row, startingAt start: Int32) throws(SQLError)
}

/// A type that can be decoded from a SQLite row using adapters.
public protocol RowDecodableWithAdapters {
    associatedtype Adapters: PureSQL.Adapters
    
    /// The indices of columns that are expected to never be nil.
    static var nonOptionalIndices: [Int32] { get }
    
    /// Initializes an instance from the given row, starting at a column index.
    ///
    /// - Parameters:
    ///   - row: The SQLite row to decode values from.
    ///   - start: The starting column index in the row.
    ///   - adapters: The adapters needed to decode some of the columns.
    /// - Throws: `SQLError` if decoding fails
    init(
        row: borrowing Row,
        startingAt start: Int32,
        adapters: Adapters
    ) throws(SQLError)
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
        PureSQL.hasRequiredColumns(
            row: row,
            startingAt: start,
            nonOptionalIndices: nonOptionalIndices
        )
    }
    
    
    /// Initializes the table structure that is embedded at the given start index.
    /// Will return `nil` if it is unable to due to missing required columns
    ///
    /// - Parameters:
    ///   - row: The row the table is embedded in.
    ///   - start: The index of the first column
    public init?(row: borrowing Row, optionallyAt start: Int32) throws(SQLError) {
        guard PureSQL.hasRequiredColumns(
            row: row,
            startingAt: start,
            nonOptionalIndices: Self.nonOptionalIndices
        ) else { return nil }
        self = try Self(row: row, startingAt: start)
    }
}

extension RowDecodableWithAdapters {
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
        PureSQL.hasRequiredColumns(
            row: row,
            startingAt: start,
            nonOptionalIndices: nonOptionalIndices
        )
    }
    
    
    /// Initializes the table structure that is embedded at the given start index.
    /// Will return `nil` if it is unable to due to missing required columns
    ///
    /// - Parameters:
    ///   - row: The row the table is embedded in.
    ///   - start: The index of the first column
    ///   - adapters: The adapters to decode the columns
    public init?(
        row: borrowing Row,
        optionallyAt start: Int32,
        adapters: Adapters
    ) throws(SQLError) {
        guard PureSQL.hasRequiredColumns(
            row: row,
            startingAt: start,
            nonOptionalIndices: Self.nonOptionalIndices
        ) else { return nil }
        self = try Self(row: row, startingAt: start, adapters: adapters)
    }
}

@inlinable func hasRequiredColumns(
    row: borrowing Row,
    startingAt start: Int32,
    nonOptionalIndices: [Int32]
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


extension Optional: RowDecodable where Wrapped: DatabasePrimitive {
    public static var nonOptionalIndices: [Int32] { Wrapped.nonOptionalIndices }
    
    public init(row: borrowing Row, startingAt start: Int32) throws(SQLError) {
        self = try row.value(at: start)
    }
}

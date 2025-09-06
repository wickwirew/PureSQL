//
//  DatabaseValueAdapter.swift
//  Otter
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation

/// A adapter that can encode and decode custom types that don't
/// necessarily have a direct map to a SQLite storage affinity type.
///
/// If the user type `INTEGER AS Bool` for instance the generated
/// code will call `decode(from primitive: Int)` for initialization
/// and `encodeToInt(value:)` for binding converted to the underlying
/// type being `INTEGER`.
///
/// There should be a `decode` and `encodeTo...` for each affinity
/// type the type can be stored too.
///
/// By default an error will be thrown on encoding and decoding
/// and its up to the type to decide whether it can be converted
/// to and from a certain affinity.
///
/// Encoding to `ANY` is NOT handled by default. Decoding is. So if
/// a value needs to support `ANY` `encodeToAny` needs to be implemented.
public protocol DatabaseValueAdapter<Value>: Sendable {
    associatedtype Value
    
    /// Initialize from the `TEXT` affinity
    func decode(from primitive: String) throws(OtterError) -> Value
    /// Initialize from the `INTEGER` affinity
    func decode(from primitive: Int) throws(OtterError) -> Value
    /// Initialize from the `REAL` affinity
    func decode(from primitive: Double) throws(OtterError) -> Value
    /// Initialize from the `BLOB` affinity
    func decode(from primitive: Data) throws(OtterError) -> Value
    /// Initialize from the `BLOB` affinity
    func decode(from primitive: SQLAny) throws(OtterError) -> Value
    
    /// Encode to the `TEXT` affinity
    func encodeToString(value: Value) throws(OtterError) -> String
    /// Encode to the `INTEGER` affinity
    func encodeToInt(value: Value) throws(OtterError) -> Int
    /// Encode to the `DOUBLE` affinity
    func encodeToDouble(value: Value) throws(OtterError) -> Double
    /// Encode to the `BLOB` affinity
    func encodeToData(value: Value) throws(OtterError) -> Data
    /// Encode to the `ANY` affinity
    func encodeToAny(value: Value) throws(OtterError) -> SQLAny
}

// By default just error out so each type can just specify
// what it can be converted from and not what it can't.
public extension DatabaseValueAdapter {
    @inlinable func decode(from primitive: String) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: String.self)
    }

    @inlinable func decode(from primitive: Int) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Int.self)
    }

    @inlinable func decode(from primitive: Double) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Double.self)
    }

    @inlinable func decode(from primitive: Data) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Data.self)
    }
    
    @inlinable func decode(from primitive: SQLAny) throws(OtterError) -> Value {
        switch primitive {
        case .string(let value): try decode(from: value)
        case .int(let value): try decode(from: value)
        case .double(let value): try decode(from: value)
        case .data(let value): try decode(from: value)
        }
    }

    @inlinable func encodeToString(value: Value) throws(OtterError) -> String {
        throw .cannotEncode(Self.self, to: String.self)
    }

    @inlinable func encodeToInt(value: Value) throws(OtterError) -> Int {
        throw .cannotEncode(Self.self, to: Int.self)
    }

    @inlinable func encodeToDouble(value: Value) throws(OtterError) -> Double {
        throw .cannotEncode(Self.self, to: Double.self)
    }

    @inlinable func encodeToData(value: Value) throws(OtterError) -> Data {
        throw .cannotEncode(Self.self, to: Data.self)
    }
}

public struct AnyDatabaseValueAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let _decodeString: @Sendable (String) throws(OtterError) -> Value
    @usableFromInline let _decodeInt: @Sendable (Int) throws(OtterError) -> Value
    @usableFromInline let _decodeDouble: @Sendable (Double) throws(OtterError) -> Value
    @usableFromInline let _decodeData: @Sendable (Data) throws(OtterError) -> Value
    @usableFromInline let _decodeSQLAny: @Sendable (SQLAny) throws(OtterError) -> Value
    @usableFromInline let _encodeToString: @Sendable (Value) throws(OtterError) -> String
    @usableFromInline let _encodeToInt: @Sendable (Value) throws(OtterError) -> Int
    @usableFromInline let _encodeToDouble: @Sendable (Value) throws(OtterError) -> Double
    @usableFromInline let _encodeToData: @Sendable (Value) throws(OtterError) -> Data
    @usableFromInline let _encodeToAny: @Sendable (Value) throws(OtterError) -> SQLAny
    
    public init(_ adapter: any DatabaseValueAdapter<Value>) {
        // Note: We define the entire closure type `(value) throws(OtterError) -> ...` due to
        // what seems to be a limitation in typed throws. Without it, it throws an error
        // for an invalid conversion.
        self._decodeString = { (value: String) throws(OtterError) -> Value in try adapter.decode(from: value) }
        self._decodeInt = { (value: Int) throws(OtterError) -> Value in try adapter.decode(from: value) }
        self._decodeDouble = { (value: Double) throws(OtterError) -> Value in try adapter.decode(from: value) }
        self._decodeData = { (value: Data) throws(OtterError) -> Value in try adapter.decode(from: value) }
        self._decodeSQLAny = { (value: SQLAny) throws(OtterError) -> Value in try adapter.decode(from: value) }
        self._encodeToString = { (value: Value) throws(OtterError) -> String in try adapter.encodeToString(value: value) }
        self._encodeToInt = { (value: Value) throws(OtterError) -> Int in try adapter.encodeToInt(value: value) }
        self._encodeToDouble = { (value: Value) throws(OtterError) -> Double in try adapter.encodeToDouble(value: value) }
        self._encodeToData = { (value: Value) throws(OtterError) -> Data in try adapter.encodeToData(value: value) }
        self._encodeToAny = { (value: Value) throws(OtterError) -> SQLAny in try adapter.encodeToAny(value: value) }
    }
    
    @inlinable public func decode(from primitive: String) throws(OtterError) -> Value {
        try _decodeString(primitive)
    }
    
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value {
        try _decodeInt(primitive)
    }
    
    @inlinable public func decode(from primitive: Double) throws(OtterError) -> Value {
        try _decodeDouble(primitive)
    }
    
    @inlinable public func decode(from primitive: Data) throws(OtterError) -> Value {
        try _decodeData(primitive)
    }
    
    @inlinable public func decode(from primitive: SQLAny) throws(OtterError) -> Value {
        try _decodeSQLAny(primitive)
    }
    
    @inlinable public func encodeToString(value: Value) throws(OtterError) -> String {
        try _encodeToString(value)
    }
    
    @inlinable public func encodeToInt(value: Value) throws(OtterError) -> Int {
        try _encodeToInt(value)
    }
    
    @inlinable public func encodeToDouble(value: Value) throws(OtterError) -> Double {
        try _encodeToDouble(value)
    }
    
    @inlinable public func encodeToData(value: Value) throws(OtterError) -> Data {
        try _encodeToData(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(OtterError) -> SQLAny {
        try _encodeToAny(value)
    }
}

// MARK: - Swift Standard Libray

public struct BoolDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Bool { primitive > 0 }
    @inlinable public func encodeToInt(value: Bool) throws(OtterError) -> Int { value ? 1 : 0 }
    @inlinable public func encodeToAny(value: Bool) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int8DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int8) throws(OtterError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int8) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int16) throws(OtterError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int16) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int32DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int32) throws(OtterError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int32) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int64DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int64) throws(OtterError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int64) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt8DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt8) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt8) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt16) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt16) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt32DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt32) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt32) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt64DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt64) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt64) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UIntDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Value { UInt(bitPattern: primitive) }
    @inlinable public func encodeToAny(value: UInt) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct FloatDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToDouble(value: Float) throws(OtterError) -> Double { Double(value) }
    @inlinable public func decode(from primitive: Double) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Float) throws(OtterError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

@available(macOS 11.0, *)
@available(iOS 14.0, *)
public struct Float16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToDouble(value: Float16) throws(OtterError) -> Double { Double(value) }
    @inlinable public func decode(from primitive: Double) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Float16) throws(OtterError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

// MARK: - Foundation

public struct UUIDDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func decode(from primitive: String) throws(OtterError) -> UUID {
        guard let uuid = UUID(uuidString: primitive) else {
            throw .invalidUuidString
        }

        return uuid
    }

    @inlinable public func decode(from primitive: Data) throws(OtterError) -> UUID {
        return primitive.withUnsafeBytes { $0.load(as: UUID.self) }
    }

    @inlinable public func encodeToString(value: UUID) throws(OtterError) -> String {
        return value.uuidString
    }

    @inlinable public func encodeToData(value: UUID) throws(OtterError) -> Data {
        var data = Data(count: 16)
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            pointer.storeBytes(of: value.uuid, as: uuid_t.self)
        }
        return data
    }
    
    @inlinable public func encodeToAny(value: UUID) throws(OtterError) -> SQLAny {
        try .string(encodeToString(value: value))
    }
}

public struct DecimalDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func encodeToDouble(value: Value) throws(OtterError) -> Double {
        Double(truncating: value as NSNumber)
    }

    @inlinable public func decode(from primitive: Double) throws(OtterError) -> Decimal {
        Decimal(primitive)
    }

    /// We do not have `String` to other floating point conversions
    /// defined but `Decimal` is a special case. People might want to
    /// use it if they need the greater precision. If its stored to
    /// a `REAL` e.g. `DOUBLE` it will lose some of that precision in
    /// the conversion so some people like to store them as a `TEXT`
    /// to preserve the precision
    @inlinable public func decode(from primitive: String) throws(OtterError) -> Decimal {
        guard let decimal = Decimal(string: primitive) else {
            throw .decodingError("Failed to initialize Decimal from '\(primitive)'")
        }

        return decimal
    }

    @inlinable public func encodeToString(value: Decimal) throws(OtterError) -> String {
        return value.description
    }
    
    @inlinable public func encodeToAny(value: Decimal) throws(OtterError) -> SQLAny {
        try .double(encodeToDouble(value: value))
    }
}

public struct  DateDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @usableFromInline nonisolated(unsafe) let formatter: ISO8601DateFormatter = {
        // Note: In the future might want to move off of this and have a custom
        // date parser cause I don't think it's performance is the best.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    @inlinable public func decode(from primitive: Int) throws(OtterError) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(primitive))
    }

    @inlinable public func decode(from primitive: Double) throws(OtterError) -> Date {
        return Date(timeIntervalSince1970: primitive)
    }
    
    @inlinable public func decode(from primitive: String) throws(OtterError) -> Date {
        guard let date = formatter.date(from: primitive) else {
            throw .cannotDecode(Date.self, from: String.self, reason: "Invalid date string: '\(primitive)'")
        }
        return date
    }
    
    @inlinable public func encodeToInt(value: Date) throws(OtterError) -> Int {
        Int(value.timeIntervalSince1970)
    }
    
    @inlinable public func encodeToDouble(value: Date) throws(OtterError) -> Double {
        value.timeIntervalSince1970
    }
    
    @inlinable public func encodeToString(value: Date) throws(OtterError) -> String {
        return formatter.string(from: value)
    }
    
    @inlinable public func encodeToAny(value: Date) throws(OtterError) -> SQLAny {
        // By default just go to double since its going to be the fastest
        try .double(encodeToDouble(value: value))
    }
}

public struct URLDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func encodeToString(value: URL) throws(OtterError) -> String {
        value.absoluteString
    }
    
    @inlinable public func encodeToAny(value: URL) throws(OtterError) -> SQLAny {
        .string(value.absoluteString)
    }
    
    @inlinable public func decode(from primitive: String) throws(OtterError) -> URL {
        guard let url = URL(string: primitive) else {
            throw OtterError.cannotEncode(String.self, to: URL.self)
        }
        
        return url
    }
}

//
//  DatabaseValueAdapter.swift
//  PureSQL
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
    func decode(from primitive: String) throws(PureSQLError) -> Value
    /// Initialize from the `INTEGER` affinity
    func decode(from primitive: Int) throws(PureSQLError) -> Value
    /// Initialize from the `REAL` affinity
    func decode(from primitive: Double) throws(PureSQLError) -> Value
    /// Initialize from the `BLOB` affinity
    func decode(from primitive: Data) throws(PureSQLError) -> Value
    /// Initialize from the `BLOB` affinity
    func decode(from primitive: SQLAny) throws(PureSQLError) -> Value
    
    /// Encode to the `TEXT` affinity
    func encodeToString(value: Value) throws(PureSQLError) -> String
    /// Encode to the `INTEGER` affinity
    func encodeToInt(value: Value) throws(PureSQLError) -> Int
    /// Encode to the `DOUBLE` affinity
    func encodeToDouble(value: Value) throws(PureSQLError) -> Double
    /// Encode to the `BLOB` affinity
    func encodeToData(value: Value) throws(PureSQLError) -> Data
    /// Encode to the `ANY` affinity
    func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny
}

// By default just error out so each type can just specify
// what it can be converted from and not what it can't.
public extension DatabaseValueAdapter {
    @inlinable func decode(from primitive: String) throws(PureSQLError) -> Value {
        throw .cannotDecode(Self.self, from: String.self)
    }

    @inlinable func decode(from primitive: Int) throws(PureSQLError) -> Value {
        throw .cannotDecode(Self.self, from: Int.self)
    }

    @inlinable func decode(from primitive: Double) throws(PureSQLError) -> Value {
        throw .cannotDecode(Self.self, from: Double.self)
    }

    @inlinable func decode(from primitive: Data) throws(PureSQLError) -> Value {
        throw .cannotDecode(Self.self, from: Data.self)
    }
    
    @inlinable func decode(from primitive: SQLAny) throws(PureSQLError) -> Value {
        switch primitive {
        case .string(let value): try decode(from: value)
        case .int(let value): try decode(from: value)
        case .double(let value): try decode(from: value)
        case .data(let value): try decode(from: value)
        }
    }

    @inlinable func encodeToString(value: Value) throws(PureSQLError) -> String {
        throw .cannotEncode(Self.self, to: String.self)
    }

    @inlinable func encodeToInt(value: Value) throws(PureSQLError) -> Int {
        throw .cannotEncode(Self.self, to: Int.self)
    }

    @inlinable func encodeToDouble(value: Value) throws(PureSQLError) -> Double {
        throw .cannotEncode(Self.self, to: Double.self)
    }

    @inlinable func encodeToData(value: Value) throws(PureSQLError) -> Data {
        throw .cannotEncode(Self.self, to: Data.self)
    }
}

public struct AnyDatabaseValueAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let _decodeString: @Sendable (String) throws(PureSQLError) -> Value
    @usableFromInline let _decodeInt: @Sendable (Int) throws(PureSQLError) -> Value
    @usableFromInline let _decodeDouble: @Sendable (Double) throws(PureSQLError) -> Value
    @usableFromInline let _decodeData: @Sendable (Data) throws(PureSQLError) -> Value
    @usableFromInline let _decodeSQLAny: @Sendable (SQLAny) throws(PureSQLError) -> Value
    @usableFromInline let _encodeToString: @Sendable (Value) throws(PureSQLError) -> String
    @usableFromInline let _encodeToInt: @Sendable (Value) throws(PureSQLError) -> Int
    @usableFromInline let _encodeToDouble: @Sendable (Value) throws(PureSQLError) -> Double
    @usableFromInline let _encodeToData: @Sendable (Value) throws(PureSQLError) -> Data
    @usableFromInline let _encodeToAny: @Sendable (Value) throws(PureSQLError) -> SQLAny
    
    public init(_ adapter: any DatabaseValueAdapter<Value>) {
        // Note: We define the entire closure type `(value) throws(PureSQLError) -> ...` due to
        // what seems to be a limitation in typed throws. Without it, it throws an error
        // for an invalid conversion.
        self._decodeString = { (value: String) throws(PureSQLError) -> Value in try adapter.decode(from: value) }
        self._decodeInt = { (value: Int) throws(PureSQLError) -> Value in try adapter.decode(from: value) }
        self._decodeDouble = { (value: Double) throws(PureSQLError) -> Value in try adapter.decode(from: value) }
        self._decodeData = { (value: Data) throws(PureSQLError) -> Value in try adapter.decode(from: value) }
        self._decodeSQLAny = { (value: SQLAny) throws(PureSQLError) -> Value in try adapter.decode(from: value) }
        self._encodeToString = { (value: Value) throws(PureSQLError) -> String in try adapter.encodeToString(value: value) }
        self._encodeToInt = { (value: Value) throws(PureSQLError) -> Int in try adapter.encodeToInt(value: value) }
        self._encodeToDouble = { (value: Value) throws(PureSQLError) -> Double in try adapter.encodeToDouble(value: value) }
        self._encodeToData = { (value: Value) throws(PureSQLError) -> Data in try adapter.encodeToData(value: value) }
        self._encodeToAny = { (value: Value) throws(PureSQLError) -> SQLAny in try adapter.encodeToAny(value: value) }
    }
    
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> Value {
        try _decodeString(primitive)
    }
    
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value {
        try _decodeInt(primitive)
    }
    
    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Value {
        try _decodeDouble(primitive)
    }
    
    @inlinable public func decode(from primitive: Data) throws(PureSQLError) -> Value {
        try _decodeData(primitive)
    }
    
    @inlinable public func decode(from primitive: SQLAny) throws(PureSQLError) -> Value {
        try _decodeSQLAny(primitive)
    }
    
    @inlinable public func encodeToString(value: Value) throws(PureSQLError) -> String {
        try _encodeToString(value)
    }
    
    @inlinable public func encodeToInt(value: Value) throws(PureSQLError) -> Int {
        try _encodeToInt(value)
    }
    
    @inlinable public func encodeToDouble(value: Value) throws(PureSQLError) -> Double {
        try _encodeToDouble(value)
    }
    
    @inlinable public func encodeToData(value: Value) throws(PureSQLError) -> Data {
        try _encodeToData(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny {
        try _encodeToAny(value)
    }
}

// MARK: - Swift Standard Libray

public struct BoolDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Bool { primitive > 0 }
    @inlinable public func encodeToInt(value: Bool) throws(PureSQLError) -> Int { value ? 1 : 0 }
    @inlinable public func encodeToAny(value: Bool) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int8DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int8) throws(PureSQLError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int8) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int16) throws(PureSQLError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int16) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int32DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int32) throws(PureSQLError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int32) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct Int64DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: Int64) throws(PureSQLError) -> Int { Int(value) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Int64) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt8DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt8) throws(PureSQLError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt8) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt16) throws(PureSQLError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt16) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt32DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt32) throws(PureSQLError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt32) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UInt64DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt64) throws(PureSQLError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public func encodeToAny(value: UInt64) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct UIntDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToInt(value: UInt) throws(PureSQLError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value { UInt(bitPattern: primitive) }
    @inlinable public func encodeToAny(value: UInt) throws(PureSQLError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public struct FloatDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToDouble(value: Float) throws(PureSQLError) -> Double { Double(value) }
    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Float) throws(PureSQLError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

@available(macOS 11.0, *)
@available(iOS 14.0, *)
public struct Float16DatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    @inlinable public func encodeToDouble(value: Float16) throws(PureSQLError) -> Double { Double(value) }
    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Value { Value(primitive) }
    @inlinable public func encodeToAny(value: Float16) throws(PureSQLError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

// MARK: - Foundation

public struct UUIDDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> UUID {
        guard let uuid = UUID(uuidString: primitive) else {
            throw .invalidUuidString
        }

        return uuid
    }

    @inlinable public func decode(from primitive: Data) throws(PureSQLError) -> UUID {
        return primitive.withUnsafeBytes { $0.load(as: UUID.self) }
    }

    @inlinable public func encodeToString(value: UUID) throws(PureSQLError) -> String {
        return value.uuidString
    }

    @inlinable public func encodeToData(value: UUID) throws(PureSQLError) -> Data {
        var data = Data(count: 16)
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            pointer.storeBytes(of: value.uuid, as: uuid_t.self)
        }
        return data
    }
    
    @inlinable public func encodeToAny(value: UUID) throws(PureSQLError) -> SQLAny {
        try .string(encodeToString(value: value))
    }
}

public struct DecimalDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func encodeToDouble(value: Value) throws(PureSQLError) -> Double {
        Double(truncating: value as NSNumber)
    }

    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Decimal {
        Decimal(primitive)
    }

    /// We do not have `String` to other floating point conversions
    /// defined but `Decimal` is a special case. People might want to
    /// use it if they need the greater precision. If its stored to
    /// a `REAL` e.g. `DOUBLE` it will lose some of that precision in
    /// the conversion so some people like to store them as a `TEXT`
    /// to preserve the precision
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> Decimal {
        guard let decimal = Decimal(string: primitive) else {
            throw .decodingError("Failed to initialize Decimal from '\(primitive)'")
        }

        return decimal
    }

    @inlinable public func encodeToString(value: Decimal) throws(PureSQLError) -> String {
        return value.description
    }
    
    @inlinable public func encodeToAny(value: Decimal) throws(PureSQLError) -> SQLAny {
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
    
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(primitive))
    }

    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Date {
        return Date(timeIntervalSince1970: primitive)
    }
    
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> Date {
        guard let date = formatter.date(from: primitive) else {
            throw .cannotDecode(Date.self, from: String.self, reason: "Invalid date string: '\(primitive)'")
        }
        return date
    }
    
    @inlinable public func encodeToInt(value: Date) throws(PureSQLError) -> Int {
        Int(value.timeIntervalSince1970)
    }
    
    @inlinable public func encodeToDouble(value: Date) throws(PureSQLError) -> Double {
        value.timeIntervalSince1970
    }
    
    @inlinable public func encodeToString(value: Date) throws(PureSQLError) -> String {
        return formatter.string(from: value)
    }
    
    @inlinable public func encodeToAny(value: Date) throws(PureSQLError) -> SQLAny {
        // By default just go to double since its going to be the fastest
        try .double(encodeToDouble(value: value))
    }
}

public struct URLDatabaseValueAdapter: DatabaseValueAdapter {
    public init() {}
    
    @inlinable public func encodeToString(value: URL) throws(PureSQLError) -> String {
        value.absoluteString
    }
    
    @inlinable public func encodeToAny(value: URL) throws(PureSQLError) -> SQLAny {
        .string(value.absoluteString)
    }
    
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> URL {
        guard let url = URL(string: primitive) else {
            throw PureSQLError.cannotEncode(String.self, to: URL.self)
        }
        
        return url
    }
}


/// A convenience adapter for a type that can only be encoded to a `String`
public struct AsStringAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let encode: @Sendable (Value) throws(PureSQLError) -> String
    @usableFromInline let decode: @Sendable (String) throws(PureSQLError) -> Value
    
    public init(
        encode: @Sendable @escaping (Value) throws(PureSQLError) -> String,
        decode: @Sendable @escaping (String) throws(PureSQLError) -> Value
    ) {
        self.encode = encode
        self.decode = decode
    }
    
    @inlinable public func encodeToString(value: Value) throws(PureSQLError) -> String {
        try encode(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny {
        try .string(encode(value))
    }
    
    @inlinable public func decode(from primitive: String) throws(PureSQLError) -> Value {
        try decode(primitive)
    }
}

/// A convenience adapter for a type that can only be encoded to a `Int`
public struct AsIntAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let encode: @Sendable (Value) throws(PureSQLError) -> Int
    @usableFromInline let decode: @Sendable (Int) throws(PureSQLError) -> Value
    
    public init(
        encode: @Sendable @escaping (Value) throws(PureSQLError) -> Int,
        decode: @Sendable @escaping (Int) throws(PureSQLError) -> Value
    ) {
        self.encode = encode
        self.decode = decode
    }
    
    @inlinable public func encodeToInt(value: Value) throws(PureSQLError) -> Int {
        try encode(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny {
        try .int(encode(value))
    }
    
    @inlinable public func decode(from primitive: Int) throws(PureSQLError) -> Value {
        try decode(primitive)
    }
}

/// A convenience adapter for a type that can only be encoded to a `Double`
public struct AsDoubleAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let encode: @Sendable (Value) throws(PureSQLError) -> Double
    @usableFromInline let decode: @Sendable (Double) throws(PureSQLError) -> Value
    
    public init(
        encode: @Sendable @escaping (Value) throws(PureSQLError) -> Double,
        decode: @Sendable @escaping (Double) throws(PureSQLError) -> Value
    ) {
        self.encode = encode
        self.decode = decode
    }
    
    @inlinable public func encodeToDouble(value: Value) throws(PureSQLError) -> Double {
        try encode(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny {
        try .double(encode(value))
    }
    
    @inlinable public func decode(from primitive: Double) throws(PureSQLError) -> Value {
        try decode(primitive)
    }
}

/// A convenience adapter for a type that can only be encoded to a `Data`
public struct AsDataAdapter<Value>: DatabaseValueAdapter {
    @usableFromInline let encode: @Sendable (Value) throws(PureSQLError) -> Data
    @usableFromInline let decode: @Sendable (Data) throws(PureSQLError) -> Value
    
    public init(
        encode: @Sendable @escaping (Value) throws(PureSQLError) -> Data,
        decode: @Sendable @escaping (Data) throws(PureSQLError) -> Value
    ) {
        self.encode = encode
        self.decode = decode
    }
    
    @inlinable public func encodeToData(value: Value) throws(PureSQLError) -> Data {
        try encode(value)
    }
    
    @inlinable public func encodeToAny(value: Value) throws(PureSQLError) -> SQLAny {
        try .data(encode(value))
    }
    
    @inlinable public func decode(from primitive: Data) throws(PureSQLError) -> Value {
        try decode(primitive)
    }
}

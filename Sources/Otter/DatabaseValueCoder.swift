//
//  DatabaseValueCoder.swift
//  Otter
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation

/// A coder that can encode and decode custom types that don't
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
public protocol DatabaseValueCoder {
    associatedtype Value
    
    /// Initialize from the `TEXT` affinity
    static func decode(from primitive: String) throws(OtterError) -> Value
    /// Initialize from the `INTEGER` affinity
    static func decode(from primitive: Int) throws(OtterError) -> Value
    /// Initialize from the `REAL` affinity
    static func decode(from primitive: Double) throws(OtterError) -> Value
    /// Initialize from the `BLOB` affinity
    static func decode(from primitive: Data) throws(OtterError) -> Value
    /// Initialize from the `BLOB` affinity
    static func decode(from primitive: SQLAny) throws(OtterError) -> Value
    
    /// Encode to the `TEXT` affinity
    static func encodeToString(value: Value) throws(OtterError) -> String
    /// Encode to the `INTEGER` affinity
    static func encodeToInt(value: Value) throws(OtterError) -> Int
    /// Encode to the `DOUBLE` affinity
    static func encodeToDouble(value: Value) throws(OtterError) -> Double
    /// Encode to the `BLOB` affinity
    static func encodeToData(value: Value) throws(OtterError) -> Data
    /// Encode to the `ANY` affinity
    static func encodeToAny(value: Value) throws(OtterError) -> SQLAny
}

// By default just error out so each type can just specify
// what it can be converted from and not what it can't.
public extension DatabaseValueCoder {
    @inlinable static func decode(from primitive: String) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: String.self)
    }

    @inlinable static func decode(from primitive: Int) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Int.self)
    }

    @inlinable static func decode(from primitive: Double) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Double.self)
    }

    @inlinable static func decode(from primitive: Data) throws(OtterError) -> Value {
        throw .cannotDecode(Self.self, from: Data.self)
    }
    
    @inlinable static func decode(from primitive: SQLAny) throws(OtterError) -> Value {
        switch primitive {
        case .string(let value): try decode(from: value)
        case .int(let value): try decode(from: value)
        case .double(let value): try decode(from: value)
        case .data(let value): try decode(from: value)
        }
    }

    @inlinable static func encodeToString(value: Value) throws(OtterError) -> String {
        throw .cannotEncode(Self.self, to: String.self)
    }

    @inlinable static func encodeToInt(value: Value) throws(OtterError) -> Int {
        throw .cannotEncode(Self.self, to: Int.self)
    }

    @inlinable static func encodeToDouble(value: Value) throws(OtterError) -> Double {
        throw .cannotEncode(Self.self, to: Double.self)
    }

    @inlinable static func encodeToData(value: Value) throws(OtterError) -> Data {
        throw .cannotEncode(Self.self, to: Data.self)
    }
}

// MARK: - Swift Standard Libray

public enum BoolDatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Bool { primitive > 0 }
    @inlinable public static func encodeToInt(value: Bool) throws(OtterError) -> Int { value ? 1 : 0 }
    @inlinable public static func encodeToAny(value: Bool) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum Int8DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: Int8) throws(OtterError) -> Int { Int(value) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Int8) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum Int16DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: Int16) throws(OtterError) -> Int { Int(value) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Int16) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum Int32DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: Int32) throws(OtterError) -> Int { Int(value) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Int32) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum Int64DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: Int64) throws(OtterError) -> Int { Int(value) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Int64) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum UInt8DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: UInt8) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public static func encodeToAny(value: UInt8) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum UInt16DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: UInt16) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public static func encodeToAny(value: UInt16) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum UInt32DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: UInt32) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public static func encodeToAny(value: UInt32) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum UInt64DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: UInt64) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { Value(UInt(bitPattern: primitive)) }
    @inlinable public static func encodeToAny(value: UInt64) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum UIntDatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToInt(value: UInt) throws(OtterError) -> Int { Int(bitPattern: UInt(value)) }
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Value { UInt(bitPattern: primitive) }
    @inlinable public static func encodeToAny(value: UInt) throws(OtterError) -> SQLAny { try .int(encodeToInt(value: value)) }
}

public enum FloatDatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToDouble(value: Float) throws(OtterError) -> Double { Double(value) }
    @inlinable public static func decode(from primitive: Double) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Float) throws(OtterError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

@available(macOS 11.0, *)
@available(iOS 14.0, *)
public enum Float16DatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToDouble(value: Float16) throws(OtterError) -> Double { Double(value) }
    @inlinable public static func decode(from primitive: Double) throws(OtterError) -> Value { Value(primitive) }
    @inlinable public static func encodeToAny(value: Float16) throws(OtterError) -> SQLAny { try .double(encodeToDouble(value: value)) }
}

// MARK: - Foundation

public enum UUIDDatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func decode(from primitive: String) throws(OtterError) -> UUID {
        guard let uuid = UUID(uuidString: primitive) else {
            throw .invalidUuidString
        }

        return uuid
    }

    @inlinable public static func decode(from primitive: Data) throws(OtterError) -> UUID {
        return primitive.withUnsafeBytes { $0.load(as: UUID.self) }
    }

    @inlinable public static func encodeToString(value: UUID) throws(OtterError) -> String {
        return value.uuidString
    }

    @inlinable public static func encodeToData(value: UUID) throws(OtterError) -> Data {
        var data = Data(count: 16)
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            pointer.storeBytes(of: value.uuid, as: uuid_t.self)
        }
        return data
    }
    
    @inlinable public static func encodeToAny(value: UUID) throws(OtterError) -> SQLAny {
        try .string(encodeToString(value: value))
    }
}

public enum DecimalDatabaseValueCoder: DatabaseValueCoder {
    @inlinable public static func encodeToDouble(value: Value) throws(OtterError) -> Double {
        Double(truncating: value as NSNumber)
    }

    @inlinable public static func decode(from primitive: Double) throws(OtterError) -> Decimal {
        Decimal(primitive)
    }

    /// We do not have `String` to other floating point conversions
    /// defined but `Decimal` is a special case. People might want to
    /// use it if they need the greater precision. If its stored to
    /// a `REAL` e.g. `DOUBLE` it will lose some of that precision in
    /// the conversion so some people like to store them as a `TEXT`
    /// to preserve the precision
    @inlinable public static func decode(from primitive: String) throws(OtterError) -> Decimal {
        guard let decimal = Decimal(string: primitive) else {
            throw .decodingError("Failed to initialize Decimal from '\(primitive)'")
        }

        return decimal
    }

    @inlinable public static func encodeToString(value: Decimal) throws(OtterError) -> String {
        return value.description
    }
    
    @inlinable public static func encodeToAny(value: Decimal) throws(OtterError) -> SQLAny {
        try .double(encodeToDouble(value: value))
    }
}

public enum DateDatabaseValueCoder: DatabaseValueCoder {
    @usableFromInline static nonisolated(unsafe) let formatter: ISO8601DateFormatter = {
        // Note: In the future might want to move off of this and have a custom
        // date parser cause I don't think it's performance is the best.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    @inlinable public static func decode(from primitive: Int) throws(OtterError) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(primitive))
    }

    @inlinable public static func decode(from primitive: Double) throws(OtterError) -> Date {
        return Date(timeIntervalSince1970: primitive)
    }
    
    @inlinable public static func decode(from primitive: String) throws(OtterError) -> Date {
        guard let date = formatter.date(from: primitive) else {
            throw .cannotDecode(Date.self, from: String.self, reason: "Invalid date string: '\(primitive)'")
        }
        return date
    }
    
    @inlinable public static func encodeToInt(value: Date) throws(OtterError) -> Int {
        Int(value.timeIntervalSince1970)
    }
    
    @inlinable public static func encodeToDouble(value: Date) throws(OtterError) -> Double {
        value.timeIntervalSince1970
    }
    
    @inlinable public static func encodeToString(value: Date) throws(OtterError) -> String {
        return formatter.string(from: value)
    }
    
    @inlinable public static func encodeToAny(value: Date) throws(OtterError) -> SQLAny {
        // By default just go to double since its going to be the fastest
        try .double(encodeToDouble(value: value))
    }
}

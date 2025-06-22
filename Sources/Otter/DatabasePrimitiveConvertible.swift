//
//  DatabasePrimitiveConvertible.swift
//  Otter
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation

/// A type that that can be converted to different SQLite
/// storage affinity types. If the user type `INTEGER AS Bool`
/// for instance the generated code will call `Bool(primitive: Int)`
/// for initialization and `encodeToInt()` for binding automatically
/// due to the underlying type being `INTEGER`.
///
/// There should be a `init(primitive:)` and `encodeTo` for each affinity
/// type the type can be stored too.
///
/// By default an error will be thrown on encoding and decoding
/// and its up to the type to decide whether it can be converted
/// to and from a certain affinity.
public protocol DatabasePrimitiveConvertibe {
    /// Initialize from the `TEXT` affinity
    init(primitive: String) throws(OtterError)
    /// Initialize from the `INTEGER` affinity
    init(primitive: Int) throws(OtterError)
    /// Initialize from the `REAL` affinity
    init(primitive: Double) throws(OtterError)
    /// Initialize from the `BLOB` affinity
    init(primitive: Data) throws(OtterError)
    /// Encode to the `TEXT` affinity
    func encodeToString() throws(OtterError) -> String
    /// Encode to the `INTEGER` affinity
    func encodeToInt() throws(OtterError) -> Int
    /// Encode to the `DOUBLE` affinity
    func encodeToDouble() throws(OtterError) -> Double
    /// Encode to the `BLOB` affinity
    func encodeToData() throws(OtterError) -> Data
}

// By default just error out so each type can just specify
// what it can be converted from and not what it can't.
public extension DatabasePrimitiveConvertibe {
    @inlinable init(primitive: String) throws(OtterError) {
        throw .cannotDecode(Self.self, from: String.self)
    }

    @inlinable init(primitive: Int) throws(OtterError) {
        throw .cannotDecode(Self.self, from: Int.self)
    }

    @inlinable init(primitive: Double) throws(OtterError) {
        throw .cannotDecode(Self.self, from: Double.self)
    }

    @inlinable init(primitive: Data) throws(OtterError) {
        throw .cannotDecode(Self.self, from: Data.self)
    }

    @inlinable func encodeToString() throws(OtterError) -> String {
        throw .cannotEncode(Self.self, to: String.self)
    }

    @inlinable func encodeToInt() throws(OtterError) -> Int {
        throw .cannotEncode(Self.self, to: Int.self)
    }

    @inlinable func encodeToDouble() throws(OtterError) -> Double {
        throw .cannotEncode(Self.self, to: Double.self)
    }

    @inlinable func encodeToData() throws(OtterError) -> Data {
        throw .cannotEncode(Self.self, to: Data.self)
    }
}

// MARK: - Swift Standard Libray

extension Bool: DatabasePrimitiveConvertibe {
    @inlinable public init(primitive: Int) throws(OtterError) { self = primitive > 0 }
    @inlinable public func encodeToInt() throws(OtterError) -> Int { self ? 1 : 0 }
}

extension Int8: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(self) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(primitive) }
}

extension Int16: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(self) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(primitive) }
}

extension Int32: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(self) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(primitive) }
}

extension Int64: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(self) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(primitive) }
}

extension UInt8: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(bitPattern: UInt(self)) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(UInt(bitPattern: primitive)) }
}

extension UInt16: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(bitPattern: UInt(self)) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(UInt(bitPattern: primitive)) }
}

extension UInt32: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(bitPattern: UInt(self)) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(UInt(bitPattern: primitive)) }
}

extension UInt64: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(bitPattern: UInt(self)) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = Self(UInt(bitPattern: primitive)) }
}

extension UInt: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToInt() throws(OtterError) -> Int { Int(bitPattern: UInt(self)) }
    @inlinable public init(primitive: Int) throws(OtterError) { self = UInt(bitPattern: primitive) }
}

extension Float: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToDouble() throws(OtterError) -> Double { Double(self) }
    @inlinable public init(primitive: Double) throws(OtterError) { self = Self(primitive) }
}

@available(macOS 11.0, *)
@available(iOS 14.0, *)
extension Float16: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToDouble() throws(OtterError) -> Double { Double(self) }
    @inlinable public init(primitive: Double) throws(OtterError) { self = Self(primitive) }
}

// MARK: - Foundation

extension UUID: DatabasePrimitiveConvertibe {
    @inlinable public init(primitive: String) throws(OtterError) {
        guard let uuid = UUID(uuidString: primitive) else {
            throw .invalidUuidString
        }

        self = uuid
    }

    @inlinable public init(primitive: Data) throws(OtterError) {
        self = primitive.withUnsafeBytes { $0.load(as: UUID.self) }
    }

    @inlinable public func encodeToString() throws(OtterError) -> String {
        return uuidString
    }

    @inlinable public func encodeToData() throws(OtterError) -> Data {
        var data = Data(count: 16)
        data.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) in
            pointer.storeBytes(of: self.uuid, as: uuid_t.self)
        }
        return data
    }
}

extension Decimal: DatabasePrimitiveConvertibe {
    @inlinable public func encodeToDouble() throws(OtterError) -> Double {
        Double(truncating: self as NSNumber)
    }

    @inlinable public init(primitive: Double) throws(OtterError) {
        self = Self(primitive)
    }

    /// We do not have `String` to other floating point conversions
    /// defined but `Decimal` is a special case. People might want to
    /// use it if they need the greater precision. If its stored to
    /// a `REAL` e.g. `DOUBLE` it will lose some of that precision in
    /// the conversion so some people like to store them as a `TEXT`
    /// to preserve the precision
    @inlinable public init(primitive: String) throws(OtterError) {
        guard let decimal = Decimal(string: primitive) else {
            throw .decodingError("Failed to initialize Decimal from '\(primitive)'")
        }

        self = decimal
    }

    @inlinable public func encodeToString() throws(OtterError) -> String {
        return description
    }
}

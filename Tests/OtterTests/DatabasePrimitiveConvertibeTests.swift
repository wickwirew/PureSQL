//
//  DatabasePrimitiveConvertibeTests.swift
//  Otter
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation
@testable import Otter
import Testing

@Suite
struct DatabasePrimitiveConvertibeTests {
    @Test(arguments: [Int8.min, Int8.max])
    func int8CanBeConvertedToInt(value: Int8) throws {
        let stored = try Int8DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try Int8DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int16.min, Int16.max])
    func int16CanBeConvertedToInt(value: Int16) throws {
        let stored = try Int16DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try Int16DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int32.min, Int32.max])
    func int32CanBeConvertedToInt(value: Int32) throws {
        let stored = try Int32DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try Int32DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt8.min, UInt8.max])
    func uint8CanBeConvertedToInt(value: UInt8) throws {
        let stored = try UInt8DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try UInt8DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt16.min, UInt16.max])
    func uint16CanBeConvertedToInt(value: UInt16) throws {
        let stored = try UInt16DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try UInt16DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt32.min, UInt32.max])
    func uint32CanBeConvertedToInt(value: UInt32) throws {
        let stored = try UInt32DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try UInt32DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt64.min, UInt64.max])
    func uint64CanBeConvertedToInt(value: UInt64) throws {
        let stored = try UInt64DatabaseValueCoder.encodeToInt(value: value)
        let decoded = try UInt64DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Float.leastNormalMagnitude, Float.greatestFiniteMagnitude])
    func floatCanBeConvertedToDouble(value: Float) throws {
        let stored = try FloatDatabaseValueCoder.encodeToDouble(value: value)
        let decoded = try FloatDatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @available(macOS 11.0, *)
    @available(iOS 14.0, *)
    @Test(arguments: [Float16.leastNormalMagnitude, Float16.greatestFiniteMagnitude])
    func float16CanBeConvertedToDouble(value: Float16) throws {
        let stored = try Float16DatabaseValueCoder.encodeToDouble(value: value)
        let decoded = try Float16DatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToString() throws {
        let value = UUID()
        let stored = try UUIDDatabaseValueCoder.encodeToString(value: value)
        let decoded = try UUIDDatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToData() throws {
        let value = UUID()
        let stored = try UUIDDatabaseValueCoder.encodeToData(value: value)
        let decoded = try UUIDDatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func decimalCanBeConvertedToDouble() throws {
        let value: Decimal = 348_520
        let stored = try DecimalDatabaseValueCoder.encodeToDouble(value: value)
        let decoded = try DecimalDatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Decimal.leastNormalMagnitude, Decimal.greatestFiniteMagnitude])
    func decimalCanBeConvertedToString(value: Decimal) throws {
        let stored = try DecimalDatabaseValueCoder.encodeToString(value: value)
        let decoded = try DecimalDatabaseValueCoder.decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func dateISO8601() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueCoder.encodeToString(value: value)
        let decoded = try DateDatabaseValueCoder.decode(from: stored)
        #expect(stored == "2025-06-29T17:58:18Z")
        #expect(value == decoded)
    }
    
    @Test func dateTimestamp_Int() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueCoder.encodeToInt(value: value)
        let decoded = try DateDatabaseValueCoder.decode(from: stored)
        #expect(stored == 1751219898)
        #expect(value == decoded)
    }
    
    @Test func dateTimestamp_Double() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueCoder.encodeToDouble(value: value)
        let decoded = try DateDatabaseValueCoder.decode(from: stored)
        #expect(stored == 1751219898)
        #expect(value == decoded)
    }
}

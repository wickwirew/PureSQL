//
//  DatabaseValueAdapterTests.swift
//  Otter
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation
@testable import Otter
import Testing

@Suite
struct DatabaseValueAdapterTests {
    @Test(arguments: [Int8.min, Int8.max])
    func int8CanBeConvertedToInt(value: Int8) throws {
        let stored = try Int8DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try Int8DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int16.min, Int16.max])
    func int16CanBeConvertedToInt(value: Int16) throws {
        let stored = try Int16DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try Int16DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int32.min, Int32.max])
    func int32CanBeConvertedToInt(value: Int32) throws {
        let stored = try Int32DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try Int32DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt8.min, UInt8.max])
    func uint8CanBeConvertedToInt(value: UInt8) throws {
        let stored = try UInt8DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try UInt8DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt16.min, UInt16.max])
    func uint16CanBeConvertedToInt(value: UInt16) throws {
        let stored = try UInt16DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try UInt16DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt32.min, UInt32.max])
    func uint32CanBeConvertedToInt(value: UInt32) throws {
        let stored = try UInt32DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try UInt32DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt64.min, UInt64.max])
    func uint64CanBeConvertedToInt(value: UInt64) throws {
        let stored = try UInt64DatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try UInt64DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Float.leastNormalMagnitude, Float.greatestFiniteMagnitude])
    func floatCanBeConvertedToDouble(value: Float) throws {
        let stored = try FloatDatabaseValueAdapter().encodeToDouble(value: value)
        let decoded = try FloatDatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @available(macOS 11.0, *)
    @available(iOS 14.0, *)
    @Test(arguments: [Float16.leastNormalMagnitude, Float16.greatestFiniteMagnitude])
    func float16CanBeConvertedToDouble(value: Float16) throws {
        let stored = try Float16DatabaseValueAdapter().encodeToDouble(value: value)
        let decoded = try Float16DatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToString() throws {
        let value = UUID()
        let stored = try UUIDDatabaseValueAdapter().encodeToString(value: value)
        let decoded = try UUIDDatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToData() throws {
        let value = UUID()
        let stored = try UUIDDatabaseValueAdapter().encodeToData(value: value)
        let decoded = try UUIDDatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func decimalCanBeConvertedToDouble() throws {
        let value: Decimal = 348_520
        let stored = try DecimalDatabaseValueAdapter().encodeToDouble(value: value)
        let decoded = try DecimalDatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Decimal.leastNormalMagnitude, Decimal.greatestFiniteMagnitude])
    func decimalCanBeConvertedToString(value: Decimal) throws {
        let stored = try DecimalDatabaseValueAdapter().encodeToString(value: value)
        let decoded = try DecimalDatabaseValueAdapter().decode(from: stored)
        #expect(value == decoded)
    }
    
    @Test func dateISO8601() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueAdapter().encodeToString(value: value)
        let decoded = try DateDatabaseValueAdapter().decode(from: stored)
        #expect(stored == "2025-06-29T17:58:18Z")
        #expect(value == decoded)
    }
    
    @Test func dateTimestamp_Int() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueAdapter().encodeToInt(value: value)
        let decoded = try DateDatabaseValueAdapter().decode(from: stored)
        #expect(stored == 1751219898)
        #expect(value == decoded)
    }
    
    @Test func dateTimestamp_Double() throws {
        let value = Date(timeIntervalSince1970: 1751219898)
        let stored = try DateDatabaseValueAdapter().encodeToDouble(value: value)
        let decoded = try DateDatabaseValueAdapter().decode(from: stored)
        #expect(stored == 1751219898)
        #expect(value == decoded)
    }
    
    @Test func customDatabaseValueAdapter() async throws {
        let db: TestDB = try .inMemory(
            adapters: TestDB.Adapters(
                numberPrefix: NumberPrefixAdapter()
            )
        )
        
        let date = Date(timeIntervalSince1970: 1751219898)
        try await db.insert.execute(with: .init(optionalNumber: 200, number: 100, date: date))
        
        let result = try await db.all.execute().first
        
        #expect(result == .init(optionalNumber: 200, number: 100, date: date))
    }
    
    @Database
    struct TestDB {
        @Query("INSERT INTO hasValues VALUES (?, ?, ?)")
        var insert: any InsertQuery
        
        @Query("SELECT * FROM hasValues")
        var all: any AllQuery
        
        static var migrations: [String] {
            return [
                """
                CREATE TABLE hasValues (
                    optionalNumber TEXT AS Int64 USING NumberPrefix,
                    number TEXT AS Int64 USING NumberPrefix NOT NULL,
                    date INTEGER AS Date
                )
                """
            ]
        }
    }
    
    struct NumberPrefixAdapter: DatabaseValueAdapter {
        typealias Value = Int64
        
        func encodeToString(value: Int64) throws(OtterError) -> String {
            return "Prefix: \(value)"
        }
        
        func decode(from primitive: String) throws(OtterError) -> Int64 {
            Int64(primitive.replacingOccurrences(of: "Prefix: ", with: ""))!
        }
        
        func encodeToAny(value: Int64) throws(Otter.OtterError) -> Otter.SQLAny {
            try .string(encodeToString(value: value))
        }
    }
}

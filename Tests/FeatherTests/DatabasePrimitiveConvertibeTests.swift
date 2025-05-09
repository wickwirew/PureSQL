//
//  DatabasePrimitiveConvertibeTests.swift
//  Feather
//
//  Created by Wes Wickwire on 5/8/25.
//

import Foundation
import Testing
@testable import Feather

@Suite
struct DatabasePrimitiveConvertibeTests {
    @Test(arguments: [Int8.min, Int8.max])
    func int8CanBeConvertedToInt(value: Int8) throws {
        let stored = try value.encodeToInt()
        let decoded = try Int8(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int16.min, Int16.max])
    func int16CanBeConvertedToInt(value: Int16) throws {
        let stored = try value.encodeToInt()
        let decoded = try Int16(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Int32.min, Int32.max])
    func int32CanBeConvertedToInt(value: Int32) throws {
        let stored = try value.encodeToInt()
        let decoded = try Int32(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt8.min, UInt8.max])
    func uint8CanBeConvertedToInt(value: UInt8) throws {
        let stored = try value.encodeToInt()
        let decoded = try UInt8(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt16.min, UInt16.max])
    func uint16CanBeConvertedToInt(value: UInt16) throws {
        let stored = try value.encodeToInt()
        let decoded = try UInt16(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [UInt32.min, UInt32.max])
    func uint32CanBeConvertedToInt(value: UInt32) throws {
        let stored = try value.encodeToInt()
        let decoded = try UInt32(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Float.leastNormalMagnitude, Float.greatestFiniteMagnitude])
    func floatCanBeConvertedToDouble(value: Float) throws {
        let stored = try value.encodeToDouble()
        let decoded = try Float(primitive: stored)
        #expect(value == decoded)
    }
    
    @available(macOS 11.0, *)
    @available(iOS 14.0, *)
    @Test(arguments: [Float16.leastNormalMagnitude, Float16.greatestFiniteMagnitude])
    func float16CanBeConvertedToDouble(value: Float16) throws {
        let stored = try value.encodeToDouble()
        let decoded = try Float16(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToString() throws {
        let value = UUID()
        let stored = try value.encodeToString()
        let decoded = try UUID(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test func uuidCanBeConvertedToData() throws {
        let value = UUID()
        let stored = try value.encodeToData()
        let decoded = try UUID(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test func decimalCanBeConvertedToDouble() throws {
        let value: Decimal = 348520
        let stored = try value.encodeToDouble()
        let decoded = try Decimal(primitive: stored)
        #expect(value == decoded)
    }
    
    @Test(arguments: [Decimal.leastNormalMagnitude, Decimal.greatestFiniteMagnitude])
    func decimalCanBeConvertedToString(value: Decimal) throws {
        let stored = try value.encodeToString()
        let decoded = try Decimal(primitive: stored)
        #expect(value == decoded)
    }
}

//
//  DuplicateDictionaryTests.swift
//  Otter
//
//  Created by Wes Wickwire on 5/31/25.
//

@testable import Compiler
import Testing

@Suite
struct DuplicateDictionaryTests {
    @Test func appendSingleElement() {
        var dict = DuplicateDictionary<String, Int>()
        dict.append(1, for: "foo")
        
        #expect(dict.count == 1)
        
        let foo = dict["foo"]
        #expect(foo.count == 1)
    }
    
    @Test func appendManyElementsWithDifferentKeys() {
        var dict = DuplicateDictionary<String, Int>()
        dict.append(1, for: "foo")
        dict.append(2, for: "bar")
        
        #expect(dict.count == 2)
        
        let foo = dict["foo"]
        #expect(foo.count == 1)
        
        let bar = dict["bar"]
        #expect(bar.count == 1)
    }
    
    @Test func appendManyElementsWithDuplicateKeys() {
        var dict = DuplicateDictionary<String, Int>()
        dict.append(1, for: "foo")
        dict.append(2, for: "foo")
        
        #expect(dict.count == 2)
        
        let foo = dict["foo"]
        #expect(foo.count == 2)
        #expect(foo.map(\.self) == [1, 2])
    }
    
    @Test func getByIndexCanGetDuplicates() {
        var dict = DuplicateDictionary<String, Int>()
        dict.append(1, for: "foo")
        dict.append(2, for: "bar")
        dict.append(3, for: "foo")
        
        #expect(dict.count == 3)
        #expect(dict[0] == ("foo", 1))
        #expect(dict[1] == ("bar", 2))
        #expect(dict[2] == ("foo", 3))
    }
}

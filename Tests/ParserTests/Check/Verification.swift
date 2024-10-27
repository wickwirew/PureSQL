//
//  Verification.swift
//  SQL
//
//  Created by Wes Wickwire on 10/27/24.
//

struct Verification {
    var name: String?
    var properties: [Element]
    
    indirect enum Element {
        case string(String, String)
        case verification(String, Verification, indented: Bool = true)
        
        static func string<V: CustomStringConvertible>(_ name: String, value: V) -> Element {
            return .string(name, value.description)
        }
        
        static func optional<V: CustomStringConvertible>(_ name: String, value: V?) -> Element {
            return .string(name, value?.description ?? "none")
        }
        
        static func verification<V: Verifiable>(_ name: String, value: V, indented: Bool = true) -> Element {
            return .verification(name, value.verification, indented: indented)
        }
    }
    
    init(_ name: String? = nil, properties: [Element]) {
        self.name = name
        self.properties = properties
    }
    
    init(_ name: String? = nil, properties: (inout [Element]) throws -> Void) rethrows {
        self.name = name
        self.properties = []
        try properties(&self.properties)
    }
    
    var description: String {
        return description(indent: 0)
    }
    
    func description(indent: Int) -> String {
        let elements: [String] = properties.map { property in
            switch property {
            case let .string(name, value):
                return "\(name): \(value)"
            case let .verification(name, verification, indented):
                if indented {
                    let description = verification.description(indent: indent + 1)
                    let indentation = String(repeating: " ", count: (indent + 1) * 2)
                    return "\n\(indentation)\(name): \(description)"
                } else {
                    let description = verification.description(indent: indent)
                    return "\(name): \(description)"
                }
            }
        }
        
        if let name {
            return "(\(name) \(elements.joined(separator: ", ")))"
        } else {
            return "(\(elements.joined(separator: ", ")))"
        }
    }
}

protocol Verifiable {
    var verification: Verification { get }
}

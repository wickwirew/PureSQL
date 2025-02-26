//
//  PragmaAnalyzer.swift
//  Feather
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct FeatherPragmas: OptionSet, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let requireStrictTables = FeatherPragmas(rawValue: 1 << 0)
    
    public enum Keys {
        public static let requireStrictTables = "feather_require_strict_tables"
    }
}

struct PragmaAnalyzer {
    private(set) var featherPragmas: FeatherPragmas
    private(set) var diagnostics = Diagnostics()
    
    init(featherPragmas: FeatherPragmas = FeatherPragmas()) {
        self.featherPragmas = featherPragmas
    }
    
    func isOn(_ pragma: FeatherPragmas) -> Bool {
        return featherPragmas.contains(pragma)
    }
    
    mutating func handle(pragma: PragmaStmt) {
        switch pragma.name.value {
        case FeatherPragmas.Keys.requireStrictTables:
            guard let expr = pragma.value else {
                diagnostics.add(.init("Missing value, expected boolean", at: pragma.range))
                return
            }
            
            if isTrue(expr) {
                featherPragmas.insert(.requireStrictTables)
            } else {
                featherPragmas.remove(.requireStrictTables)
            }
        case "journal_mode":
            diagnostics.add(.init(
                "Cannot set 'journal_mode', this is set by database connection",
                at: pragma.range
            ))
        default:
            // TODO: Eventually analyze all pragmas but initially out of scope
            break
        }
    }
    
    private mutating func isTrue(_ value: PragmaStmt.Value) -> Bool {
        return switch value {
        case .on, .true, .one, .yes: true
        case .off, .false, .zero, .no: false
        }
    }
}

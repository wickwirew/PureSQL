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
    private var isStaticallyTrue = IsStaticallyTrue(allowOnOff: true)
    
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
                featherPragmas.remove(.requireStrictTables)
            } else {
                featherPragmas.insert(.requireStrictTables)
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
    
    private mutating func isTrue(_ expr: ExprSyntax) -> Bool {
        guard expr.accept(visitor: &isStaticallyTrue) else {
            diagnostics.add(.init(
                "Value is not a static boolean, expected TRUE, FALSE, 1 or 0",
                at: expr.range
            ))
            return false
        }
        
        return true
    }
}

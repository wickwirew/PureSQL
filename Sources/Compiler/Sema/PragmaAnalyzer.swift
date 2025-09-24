//
//  PragmaAnalyzer.swift
//  PureSQL
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct PureSQLPragmas: OptionSet, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let requireStrictTables = PureSQLPragmas(rawValue: 1 << 0)
    
    public enum Keys {
        public static let requireStrictTables = "puresql_require_strict_tables"
    }
}

struct PragmaAnalyzer {
    private(set) var puresqlPragmas: PureSQLPragmas
    private var diagnostics = Diagnostics()
    private var isStaticallyTrue = IsStaticallyTrue(allowOnOffYesNo: true)
    
    init(puresqlPragmas: PureSQLPragmas = PureSQLPragmas()) {
        self.puresqlPragmas = puresqlPragmas
    }
    
    var allDiagnostics: Diagnostics {
        return diagnostics.merging(isStaticallyTrue.diagnostics)
    }
    
    func isOn(_ pragma: PureSQLPragmas) -> Bool {
        return puresqlPragmas.contains(pragma)
    }
    
    mutating func handle(pragma: PragmaStmtSyntax) {
        switch pragma.name.value {
        case PureSQLPragmas.Keys.requireStrictTables:
            guard let expr = pragma.value else {
                diagnostics.add(.init("Missing value, expected integerean", at: pragma.location))
                return
            }
            
            if isStaticallyTrue.isTrue(expr) {
                puresqlPragmas.insert(.requireStrictTables)
            } else {
                puresqlPragmas.remove(.requireStrictTables)
            }
        case "journal_mode":
            diagnostics.add(.init(
                "Cannot set 'journal_mode', this is set by database connection",
                at: pragma.location
            ))
        default:
            // TODO: Eventually analyze all pragmas but initially out of scope
            break
        }
    }
}

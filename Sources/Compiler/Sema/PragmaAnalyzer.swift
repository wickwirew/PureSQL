//
//  PragmaAnalyzer.swift
//  Otter
//
//  Created by Wes Wickwire on 2/21/25.
//

public struct OtterPragmas: OptionSet, Sendable {
    public let rawValue: UInt8
    
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    public static let requireStrictTables = OtterPragmas(rawValue: 1 << 0)
    
    public enum Keys {
        public static let requireStrictTables = "feather_require_strict_tables"
    }
}

struct PragmaAnalyzer {
    private(set) var featherPragmas: OtterPragmas
    private var diagnostics = Diagnostics()
    private var isStaticallyTrue = IsStaticallyTrue(allowOnOffYesNo: true)
    
    init(featherPragmas: OtterPragmas = OtterPragmas()) {
        self.featherPragmas = featherPragmas
    }
    
    var allDiagnostics: Diagnostics {
        return diagnostics.merging(isStaticallyTrue.diagnostics)
    }
    
    func isOn(_ pragma: OtterPragmas) -> Bool {
        return featherPragmas.contains(pragma)
    }
    
    mutating func handle(pragma: PragmaStmtSyntax) {
        switch pragma.name.value {
        case OtterPragmas.Keys.requireStrictTables:
            guard let expr = pragma.value else {
                diagnostics.add(.init("Missing value, expected integerean", at: pragma.location))
                return
            }
            
            if isStaticallyTrue.isTrue(expr) {
                featherPragmas.insert(.requireStrictTables)
            } else {
                featherPragmas.remove(.requireStrictTables)
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

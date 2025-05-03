//
//  DiagnosticReporter.swift
//  Feather
//
//  Created by Wes Wickwire on 5/3/25.
//

public protocol DiagnosticReporter {
    func report(diagnostic: Diagnostic, source: String, fileName: String)
}

public struct StdoutDiagnosticReporter: DiagnosticReporter {
    public init() {}
    
    public func report(diagnostic: Diagnostic, source: String, fileName: String) {
        let source = source[diagnostic.range.range]
        
        print("""
        \(source)
        
        \(diagnostic.message)
        """)
    }
}

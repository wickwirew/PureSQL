//
//  DiagnosticReporter.swift
//  Feather
//
//  Created by Wes Wickwire on 5/3/25.
//

public protocol DiagnosticReporter {
    func report(diagnostic: Diagnostic, source: String, fileName: String)
}

extension DiagnosticReporter {
    func report(diagnostics: Diagnostics, source: String, fileName: String) {
        for diagnostic in diagnostics {
            report(diagnostic: diagnostic, source: source, fileName: fileName)
        }
    }
}

public struct StdoutDiagnosticReporter: DiagnosticReporter {
    public init() {}
    
    public let red = (open: "\u{001B}[31m", close: "\u{001B}[0m")
    public let bold = (open: "\u{001B}[1m", close: "\u{001B}[22m")
    
    public func report(diagnostic: Diagnostic, source: String, fileName: String) {
        let range = diagnostic.location.range
        let start = startOfLine(index: range.lowerBound, source: source)
        // Note: This uses `lowerBound` as well to make sure we only get one line
        let end = endOfLine(index: range.lowerBound, source: source)
        let source = source[start ..< end]
        let distanceToStart = source.distance(from: start, to: range.lowerBound)
        let indent = String(repeating: " ", count: distanceToStart)
        let underline = String(repeating: "^", count: source.distance(from: range.lowerBound, to: range.upperBound))
        
        let line = diagnostic.location.line
        let column = diagnostic.location.column
        
        print("""
        \(fileName):\(line):\(column): \(bold.open)\(red.open)error\(red.close)\(bold.close)
        
        \(source)
        \(indent)\(red.open)\(underline)\(red.close) - \(bold.open)\(diagnostic.message)\(bold.close)
        """)
    }
    
    private func startOfLine(
        index: String.Index,
        source: String
    ) -> Substring.Index {
        var index = index
        while index > source.startIndex {
            let nextIndex = source.index(before: index)
            guard !source[nextIndex].isNewline else { break }
            index = nextIndex
        }
        return index
    }
    
    private func endOfLine(
        index: String.Index,
        source: String
    ) -> Substring.Index {
        var index = index
        while index < source.endIndex, !source[index].isNewline {
            index = source.index(after: index)
        }
        return index
    }
}

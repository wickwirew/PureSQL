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
        let range = diagnostic.location.range
        let start = startOfLine(index: range.lowerBound, source: source)
        // Note: This uses `lowerBound` as well to make sure we only get one line
        let end = endOfLine(index: range.lowerBound, source: source)
        let source = source[start ..< end]
        let distanceToStart = source.distance(from: start, to: range.lowerBound)
        let indent = String(repeating: " ", count: distanceToStart)
        let underline = String(repeating: "^", count: source.distance(from: range.lowerBound, to: range.upperBound))
        
        print("""
        Error in \(fileName)
        
        \(source)
        \(indent)\(underline)
        
        \(diagnostic.message)
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

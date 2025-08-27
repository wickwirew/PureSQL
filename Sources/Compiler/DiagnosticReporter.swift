//
//  DiagnosticReporter.swift
//  Otter
//
//  Created by Wes Wickwire on 5/3/25.
//

import Foundation

public protocol DiagnosticReporter {
    func report(diagnostic: Diagnostic, source: String, filePath: String)
}

extension DiagnosticReporter {
    func report(diagnostics: Diagnostics, source: String, filePath: String) {
        for diagnostic in diagnostics.sorted(by: { $0.location.lowerBound < $1.location.lowerBound }) {
            report(diagnostic: diagnostic, source: source, filePath: filePath)
        }
    }
}

public final class StdoutDiagnosticReporter: DiagnosticReporter {
    private let dontColorize: Bool
    private var stderr = FileHandle.standardError
    
    public init(dontColorize: Bool = false) {
        self.dontColorize = dontColorize
    }
    
    static let red = ("\u{001B}[31m", "\u{001B}[0m")
    static let yellow = ("\u{001B}[33m", "\u{001B}[0m")
    static let bold = ("\u{001B}[1m", "\u{001B}[22m")
    
    var red: (open: String, close: String) {
        dontColorize ? ("", "") : Self.red
    }
    
    var yellow: (open: String, close: String) {
        dontColorize ? ("", "") : Self.yellow
    }
    
    var bold: (open: String, close: String) {
        dontColorize ? ("", "") : Self.bold
    }
    
    public func report(diagnostic: Diagnostic, source: String, filePath: String) {
        let fileName = filePath.split(separator: "/").last ?? ""
        let range = diagnostic.location.range
        let start = startOfLine(index: range.lowerBound, source: source)
        // Note: This uses `lowerBound` as well to make sure we only get one line
        let end = endOfLine(index: range.lowerBound, source: source)
        let source = source[start ..< end]
        let distanceToStart = source.distance(from: start, to: range.lowerBound)
        let indent = String(repeating: " ", count: distanceToStart)
        let underline = String(repeating: "^", count: source.distance(from: range.lowerBound, to: min(end, range.upperBound)))
        
        let line = diagnostic.location.line
        let column = diagnostic.location.column
        
        let color = switch diagnostic.level {
        case .warning: yellow
        case .error: red
        }
        
        print("""
        \(fileName):\(line):\(column): \(bold.open)\(color.open)\(diagnostic.level)\(color.close)\(bold.close):
        
        \(source)
        \(indent)\(color.open)\(underline)\(color.close) - \(bold.open)\(diagnostic.message)\(bold.close)
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

public final class XcodeDiagnosticReporter: DiagnosticReporter {
    private var stderr = FileHandle.standardError
    
    public init() {}
    
    public func report(diagnostic: Diagnostic, source: String, filePath: String) {
        let line = diagnostic.location.line
        let column = diagnostic.location.column
        print("\(filePath):\(line):\(column): \(diagnostic.level): \(diagnostic.message)", to: &stderr)
    }
}

extension FileHandle: TextOutputStream {
    public func write(_ string: String) {
        let data = Data(string.utf8)
        self.write(data)
    }
}

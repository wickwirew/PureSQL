//
//  String+Extensions.swift
//  Otter
//
//  Created by Wes Wickwire on 2/15/25.
//

extension StringProtocol {
    public var capitalizedFirst: String {
        guard !isEmpty else { return self.description }
        let first = self[startIndex]
        let rest = self[index(after: startIndex)..<endIndex]
        return "\(first.uppercased())\(rest)"
    }

    public var lowercaseFirst: String {
        guard !isEmpty else { return self.description }
        let first = self[startIndex]
        let rest = self[index(after: startIndex)..<endIndex]
        return "\(first.lowercased())\(rest)"
    }
}

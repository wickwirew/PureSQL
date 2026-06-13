//
//  FileSystemMock.swift
//  PureSQL
//
//  Created by Wes Wickwire on 6/13/26.
//

import Foundation
@testable import Compiler

final class FileSystemMock: FileSystem, @unchecked Sendable {
    let cachePath = "/cache"
    private let directories: [String: [String]]
    private let files: [String: String]
    private var written: [String: Data] = [:]

    init(directories: [String: [String]], files: [String: String]) {
        self.directories = directories
        self.files = files
    }

    func writtenContents(at path: String) -> String? {
        written[path].flatMap { String(data: $0, encoding: .utf8) }
    }

    func files(atPath path: String) throws -> [String] {
        directories[path] ?? []
    }

    func contents(of path: String) throws -> String {
        guard let contents = files[path] else {
            throw FileSystemError.fileIsNotUtf8(path: path)
        }
        return contents
    }

    func modificationDate(of path: String) throws -> Date? { nil }
    func create(directory: String) throws {}
    func write(_ data: Data, to path: String) { written[path] = data }
    func exists(at path: String) -> Bool { directories[path] != nil }
}

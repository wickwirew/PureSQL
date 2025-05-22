//
//  FileSystem.swift
//  Feather
//
//  Created by Wes Wickwire on 5/14/25.
//

import Foundation

enum FileSystemError: Error {
    case fileIsNotUtf8(path: String)
}

protocol FileSystem {
    var cachePath: String { get }
    func files(atPath path: String) throws -> [String]
    func contents(of path: String) throws -> String
    func modificationDate(of path: String) throws -> Date?
    func create(directory: String) throws
    func write(_ data: Data, to path: String)
    func exists(at path: String) -> Bool
}

extension FileSystem {
    func files(at url: URL) throws -> [String] {
        try files(atPath: url.path)
    }
    
    func contents(of url: URL) throws -> String {
        try contents(of: url.path)
    }
    
    func modificationDate(of url: URL) throws -> Date? {
        try modificationDate(of: url.path)
    }
    
    func create(directory: URL) throws {
        try create(directory: directory.path)
    }
    
    func write(_ data: Data, to url: URL) {
        write(data, to: url.path)
    }
    
    func exists(at url: URL) -> Bool {
        exists(at: url.path)
    }
}

extension FileManager: FileSystem {
    var cachePath: String {
        // Using same cache path logic as SwiftFormat
        // https://github.com/nicklockwood/SwiftFormat/blob/d35227722eb590b34a3ccaf8b40759e8910bc870/Sources/CommandLine.swift#L617
        #if os(macOS)
        if let cachePath = NSSearchPathForDirectoriesInDomains(
            .cachesDirectory, .userDomainMask, true
        ).first {
            return cachePath
        }
        #endif
        if #available(macOS 10.12, *) {
            return FileManager.default.temporaryDirectory.path
        } else {
            return "/var/tmp/"
        }
    }
    
    func modificationDate(of path: String) throws -> Date? {
        try attributesOfItem(atPath: path)[.modificationDate] as? Date
    }
    
    func files(atPath path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }
    
    func contents(of path: String) throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        
        guard let contents = String(data: data, encoding: .utf8) else {
            throw FileSystemError.fileIsNotUtf8(path: path)
        }
        
        return contents
    }
    
    func create(directory: String) throws {
        guard !fileExists(atPath: directory) else { return }
        
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )
    }
    
    func write(_ data: Data, to path: String) {
        createFile(atPath: path, contents: data)
    }
    
    func exists(at path: String) -> Bool {
        fileExists(atPath: path)
    }
}

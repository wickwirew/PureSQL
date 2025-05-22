//
//  Project.swift
//  Feather
//
//  Created by Wes Wickwire on 5/21/25.
//

import Foundation

public struct Project {
    public let url: URL
    public let migrationsDirectory: URL
    public let queriesDirectory: URL
    private let fileSystem: FileSystem
    
    public init(url: URL) {
        self = Project(url: url, fileSystem: FileManager.default)
    }
    
    init(url: URL, fileSystem: FileSystem) {
        self.url = url
        self.fileSystem = fileSystem
        self.migrationsDirectory = url.appendingPathComponent("Migrations")
        self.queriesDirectory = url.appendingPathComponent("Queries")
    }
    
    public var doesMigrationsExist: Bool {
        fileSystem.exists(at: migrationsDirectory)
    }
    
    public var doesQueriesExist: Bool {
        fileSystem.exists(at: queriesDirectory)
    }
    
    public func setup() throws {
        try fileSystem.create(directory: migrationsDirectory)
        try fileSystem.create(directory: queriesDirectory)
    }
    
    public func doesQueryExist(withName name: String) -> Bool {
        let fileUrl = queriesDirectory.appendingPathComponent("\(name).sql")
        return fileSystem.exists(at: fileUrl)
    }
    
    public func addQuery(named name: String) throws {
        guard let data = "".data(using: .utf8) else {
            fatalError("Failed to get blank string data")
        }
        
        let fileUrl = queriesDirectory.appendingPathComponent("\(name).sql")
        
        fileSystem.write(data, to: fileUrl)
    }
    
    public func addMigration() throws {
        guard let data = "".data(using: .utf8) else {
            fatalError("Failed to get blank string data")
        }
        
        let latestMigration = try fileSystem.files(at: migrationsDirectory)
            .compactMap { $0.split(separator: ".").first }
            .compactMap{ Int($0) }
            .sorted(by: >)
            .first ?? 0
        
        let fileUrl = migrationsDirectory.appendingPathComponent("\(latestMigration + 1).sql")
        
        fileSystem.write(data, to: fileUrl)
    }
}

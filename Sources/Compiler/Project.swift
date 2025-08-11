//
//  Project.swift
//  Otter
//
//  Created by Wes Wickwire on 5/21/25.
//

import Foundation

/// Small object to make interacting with the overall project structure easier.
public struct Project {
    public let generatedOutputFile: URL
    public let migrationsDirectory: URL
    public let queriesDirectory: URL
    private let fileSystem: FileSystem
    
    public init(
        generatedOutputFile: URL,
        migrationsDirectory: URL,
        queriesDirectory: URL
    ) {
        self = Project(
            generatedOutputFile: generatedOutputFile,
            migrationsDirectory: migrationsDirectory,
            queriesDirectory: queriesDirectory,
            fileSystem: FileManager.default
        )
    }
    
    init(
        generatedOutputFile: URL,
        migrationsDirectory: URL,
        queriesDirectory: URL,
        fileSystem: FileSystem
    ) {
        self.generatedOutputFile = generatedOutputFile
        self.migrationsDirectory = migrationsDirectory
        self.queriesDirectory = queriesDirectory
        self.fileSystem = fileSystem
    }
    
    public var doesMigrationsExist: Bool {
        fileSystem.exists(at: migrationsDirectory)
    }
    
    public var doesQueriesExist: Bool {
        fileSystem.exists(at: queriesDirectory)
    }
    
    public func doesQueryExist(withName name: String) -> Bool {
        let fileUrl = queriesDirectory.appendingPathComponent("\(name).sql")
        return fileSystem.exists(at: fileUrl)
    }
    
    public func addQuery(named name: String) throws {
        guard let data = "".data(using: .utf8) else {
            fatalError("Failed to get blank string data")
        }
        
        try fileSystem.create(directory: queriesDirectory)
        
        let fileUrl = queriesDirectory.appendingPathComponent("\(name).sql")
        
        fileSystem.write(data, to: fileUrl)
    }
    
    public func addMigration() throws {
        guard let data = "".data(using: .utf8) else {
            fatalError("Failed to get blank string data")
        }
        
        try fileSystem.create(directory: migrationsDirectory)
        
        let nextMigration = try fileSystem.files(at: migrationsDirectory)
            .compactMap { $0.split(separator: ".").first }
            .compactMap { Int($0) }
            .sorted(by: >)
            .first
            .map { $0 + 1 } ?? 0
        
        let fileUrl = migrationsDirectory.appendingPathComponent("\(nextMigration).sql")
        
        fileSystem.write(data, to: fileUrl)
    }
}

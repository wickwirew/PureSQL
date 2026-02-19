//
//  Config.swift
//  PureSQL
//
//  Created by Wes Wickwire on 8/5/25.
//

import Foundation
import Yams

public struct Config: Codable {
    public let queries: String
    public let migrations: String
    public let output: String?
    public let databaseName: String?
    public let additionalImports: [String]?
    public let tableNamePattern: String?
    
    enum ConfigError: Error, CustomStringConvertible {
        case invalidURL(String)
        case notFound(searchPath: String)
        
        var description: String {
            switch self {
            case .invalidURL(let url):
                "Invalid URL '\(url)'"
            case .notFound(let searchPath):
                "Config does not exist in '\(searchPath)'"
            }
        }
    }
    
    public init(at path: String) throws {
        guard var url = URL(string: path) else {
            throw ConfigError.invalidURL(path)
        }
        
        if url.lastPathComponent != "puresql.yaml" {
            url.appendPathComponent("puresql.yaml")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigError.notFound(searchPath: url.path)
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = YAMLDecoder()
        self = try decoder.decode(Config.self, from: data)
    }
    
    public func project(at path: String) throws -> Project {
        guard let url = URL(string: path) else {
            throw ConfigError.invalidURL(path)
        }
        
        return Project(
            generatedOutputFile: url.appendingPathComponent(output ?? "Queries.swift"),
            migrationsDirectory: url.appendingPathComponent(migrations),
            queriesDirectory: url.appendingPathComponent(queries)
        )
    }
}

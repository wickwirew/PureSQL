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
    
    struct NotFoundError: Error, CustomStringConvertible {
        var description: String { "Config does not exist" }
    }
    
    public init(at path: String) throws {
        var url = URL(fileURLWithPath: path)
        
        if url.lastPathComponent != "puresql.yaml" {
            url.appendPathComponent("puresql.yaml")
        }
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NotFoundError()
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = YAMLDecoder()
        self = try decoder.decode(Config.self, from: data)
    }
    
    public func project(at path: String) -> Project {
        let url = URL(fileURLWithPath: path)
        
        return Project(
            generatedOutputFile: url.appendingPathComponent(output ?? "Queries.swift"),
            migrationsDirectory: url.appendingPathComponent(migrations),
            queriesDirectory: url.appendingPathComponent(queries)
        )
    }
}

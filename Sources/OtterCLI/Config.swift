//
//  Config.swift
//  Otter
//
//  Created by Wes Wickwire on 8/5/25.
//

import Foundation
import Yams
import Compiler

struct Config: Codable {
    var queries: String
    var migrations: String
    var output: String?
    var databaseName: String?
    var additionalImports: [String]?
    
    func project(at path: String) -> Project {
        let url = URL(fileURLWithPath: path)
        
        return Project(
            generatedOutputFile: url.appendingPathComponent(output ?? "Queries.swift"),
            migrationsDirectory: url.appendingPathComponent(migrations),
            queriesDirectory: url.appendingPathComponent(queries)
        )
    }
    
    static func load(at path: String) throws -> Config {
        let url = URL(fileURLWithPath: path)
            .appendingPathComponent("otter.yaml")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw OtterError.configDoesNotExist
        }
        
        let data = try Data(contentsOf: url)
        
        let decoder = YAMLDecoder()
        return try decoder.decode(Config.self, from: data)
    }
}

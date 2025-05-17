//
//  Driver.swift
//  Feather
//
//  Created by Wes Wickwire on 5/14/25.
//

import Foundation

public actor Driver {
    private let fileSystem: FileSystem
    private var results: [Path: Output] = [:]
    private var currentSchema: Schema = [:]
    
    public typealias Path = String
    
    private var reporters: [DiagnosticReporter] = []
    
    struct Output {
        let fileName: String
        let usage: Usage
        let diagnostics: Diagnostics
        let statements: [Statement]
        let schema: Schema
        let modificationDate: Date?
    }
    
    enum Usage {
        case migration
        case queries
    }
    
    enum Error: Swift.Error {
        case invalidMigrationName(String)
    }
    
    init(fileSystem: FileSystem) {
        self.fileSystem = fileSystem
    }
    
    public init() {
        self.init(fileSystem: FileManager.default)
    }
    
    public func add(reporter: DiagnosticReporter) {
        reporters.append(reporter)
    }
    
    public func compile(path: Path) async throws {
        let migrationsPath = migrationsPath(at: path)
        let queriesPath = queriesPath(at: path)
        
        let migrationFiles = try fileSystem.files(atPath: migrationsPath)
        let queriesFiles = try fileSystem.files(atPath: queriesPath)
        
        try validateMigrations(fileNames: migrationFiles)
        
        // Migrations must be run synchronously in order.
        for migration in migrationFiles {
            try compile(file: migration, in: migrationsPath, usage: .migration)
        }
        
        // Queries can be compiled independently
        try await withThrowingTaskGroup(of: Void.self) { group in
            for query in queriesFiles {
                try compile(file: query, in: queriesPath, usage: .queries)
            }
            
            try await group.waitForAll()
        }
    }
    
    public func generate<Lang: Language>(
        language: Lang.Type,
        to path: Path?,
        options: GenerationOptions
    ) throws {
        // An array of all migrations source code
        let migrations = results.values
            .filter{ $0.usage == .migration }
            .sorted(by: { $0.fileName < $1.fileName })
            .flatMap(\.statements)
            .map(\.sanitizedSource)
        
        // An array of all queries grouped by their file name
        let queries = results.values
            .filter{ $0.usage == .queries }
            .map { ($0.fileName.split(separator: ".").first?.description, $0.statements) }
        
        let file = try Lang.generate(
            migrations: migrations,
            queries: queries,
            schema: currentSchema,
            options: options
        )
        
        if let path {
            // Create the directory of the output if needed.
            // The output path contains the file we are writing too
            // so removing the last component gives us just the directory.
            var directory = path.split(separator: "/")
            directory.removeLast()
            try fileSystem.create(directory: directory.joined(separator: "/"))
            
            try file.write(toFile: path, atomically: true, encoding: .utf8)
        } else {
            // No output path, default to stdout.
            print(file)
        }
    }

    private func compile(file: String, in base: Path, usage: Usage) throws {
        let path = "\(base)/\(file)"
        let fileContents = try fileSystem.contents(of: path)
        let modificationDate = try fileSystem.modificationDate(of: path)
    
        var compiler = Compiler()
        compiler.schema = currentSchema
        
        let diagnostics = switch usage {
        case .migration:
            compiler.compile(migration: fileContents)
        case .queries:
            compiler.compile(queries: fileContents)
        }
        
        load(diagnostics: diagnostics, source: fileContents, fileName: file)
        
        results[file] = Output(
            fileName: file,
            usage: usage,
            diagnostics: diagnostics,
            statements: compiler.queries,
            schema: compiler.schema,
            modificationDate: modificationDate
        )
        
        // Really this probably could always be set since queries cannot
        // affect schema but still worth doing.
        if usage == .migration {
            currentSchema = compiler.schema
        }
    }
    
    private func load(diagnostics: Diagnostics, source: String, fileName: String) {
        for reporter in reporters {
            reporter.report(diagnostics: diagnostics, source: source, fileName: fileName)
        }
    }
    
    /// The migrations path relative to the base path
    private func migrationsPath(at base: Path) -> Path {
        "\(base)/Migrations"
    }
    
    /// The queries path relative to the base path
    private func queriesPath(at base: Path) -> Path {
        "\(base)/Queries"
    }
    
    private func validateMigrations(
        fileNames: [String]
    ) throws {
        for fileName in fileNames.sorted() {
            let components = fileName.split(separator: ".")
            
            guard components.count == 2 else {
                throw Error.invalidMigrationName(fileName)
            }
            
            if Int(components[0]) != nil {
                throw Error.invalidMigrationName(fileName)
            }
        }
    }
}

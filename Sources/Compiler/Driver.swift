//
//  Driver.swift
//  Otter
//
//  Created by Wes Wickwire on 5/14/25.
//

import Foundation

public actor Driver {
    private let fileSystem: FileSystem
    private var results: [Path: Output] = [:]
    private var currentSchema = Schema()
    private var reporters: [DiagnosticReporter] = []
    private var logTimes = false
    
    public typealias Path = String
    
    struct Output {
        let fileName: String
        let usage: Usage
        let diagnostics: Diagnostics
        let statements: [Statement]
        let schema: Schema
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
    
    public func logTimes(_ logTimes: Bool) {
        self.logTimes = logTimes
    }
    
    public func add(reporter: DiagnosticReporter) {
        reporters.append(reporter)
    }
    
    public func compile(migrationsPath: Path, queriesPath: Path) async throws {
        try await measure("Compilation") {
            let migrationFiles = try fileSystem.files(atPath: migrationsPath)
            
            // Don't error out if it cannot find the queries. Most people will likely
            // create the migrations and try to build to see if things work before
            // they create their first query. If it can find the migrations folder
            // thats probably good enough.
            let queriesFiles = try fileSystem.exists(at: queriesPath)
                ? try fileSystem.files(atPath: queriesPath)
                : []
            
            // Migrations must be run synchronously in order.
            for migration in try sortMigrations(fileNames: migrationFiles) {
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
    }
    
    public func generate<Lang: Language>(
        language: Lang.Type,
        to path: Path?,
        options: GenerationOptions
    ) throws {
        try measure("Generation") {
            // An array of all migrations source code
            let migrations = results.values
                .filter { $0.usage == .migration }
                .sorted(by: { $0.fileName < $1.fileName })
                .flatMap(\.statements)
                .map(\.sanitizedSource)
            
            // An array of all queries grouped by their file name
            let queries = results.values
                .filter { $0.usage == .queries }
                .map { ($0.fileName.split(separator: ".").first?.description, $0.statements) }
            
            let hasDiagnostics = results.contains { $0.value.diagnostics.contains { $0.level == .error } }
            
            guard !hasDiagnostics else {
                exit(1) // Diagnostics should have already been emitted.
            }
            
            let lang = Lang(options: options)
            
            let file = try lang.generate(
                migrations: migrations,
                queries: queries,
                schema: currentSchema
            )
            
            if let path {
                // Create the directory of the output if needed.
                // The output path contains the file we are writing too
                // so removing the last component gives us just the directory.
                var directory = path.split(separator: "/")
                
                if options.createDirectoryIfNeeded, directory.count > 1 {
                    directory.removeLast()
                    
                    if !fileSystem.exists(at: directory.joined(separator: "/")) {
                        try fileSystem.create(directory: directory.joined(separator: "/"))
                    }
                }
                
                try file.write(toFile: path, atomically: true, encoding: .utf8)
            } else {
                // No output path, default to stdout.
                print(file)
            }
        }
    }

    private func compile(file: String, in base: Path, usage: Usage) throws {
        let path = "\(base)/\(file)"
        let fileContents = try fileSystem.contents(of: path)
    
        var compiler = Compiler()
        compiler.schema = currentSchema
        
        let (statements, diagnostics) = measure(file) {
            switch usage {
            case .migration:
                compiler.compile(migration: fileContents)
            case .queries:
                compiler.compile(queries: fileContents)
            }
        }
        
        report(diagnostics: diagnostics, source: fileContents, filePath: path)
        
        results[file] = Output(
            fileName: file,
            usage: usage,
            diagnostics: diagnostics,
            statements: statements,
            schema: compiler.schema
        )
        
        // Really this probably could always be set since queries cannot
        // affect schema but still worth doing.
        if usage == .migration {
            currentSchema = compiler.schema
        }
    }
    
    private func report(diagnostics: Diagnostics, source: String, filePath: String) {
        for reporter in reporters {
            reporter.report(diagnostics: diagnostics, source: source, filePath: filePath)
        }
    }
    
    /// Sorts the migration files
    private func sortMigrations(
        fileNames: [String]
    ) throws -> [String] {
        return try fileNames.sorted { lhs, rhs in
            try migrationNumber(fileName: lhs) < migrationNumber(fileName: rhs)
        }
    }
    
    /// Gets the migration number from the migration file name
    private func migrationNumber(fileName: String) throws -> Int {
        let components = fileName.split(separator: ".")
        
        guard components.count == 2 else {
            throw Error.invalidMigrationName(fileName)
        }
        
        guard let number = Int(components[0]) else {
            throw Error.invalidMigrationName(fileName)
        }
        
        return number
    }
    
    func measure<Result>(
        _ taskName: @autoclosure () -> String,
        _ execute: () throws -> Result
    ) rethrows -> Result {
        guard logTimes else { return try execute() }
        let start = Date()
        let result = try execute()
        let duration = Date().timeIntervalSince(start)
        print("[TIME] \(taskName()) took \(String(format: "%.5f", duration))s")
        return result
    }
    
    func measure<Result: Sendable>(
        _ taskName: @autoclosure () -> String,
        _ execute: () async throws -> Result
    ) async rethrows -> Result {
        guard logTimes else { return try await execute() }
        let start = Date()
        let result = try await execute()
        let duration = Date().timeIntervalSince(start)
        print("[TIME] \(taskName()) took \(String(format: "%.5f", duration))s")
        return result
    }
}
struct Foot: Swift.Error {}

//
//  Language.swift
//  PureSQL
//
//  Created by Wes Wickwire on 4/28/25.
//

import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder
import Foundation

public protocol Language {
    init(options: GenerationOptions)
    
    var boolName: String { get }
    
    /// A list of types that have builtin adapters supplied by the library.
    /// Note: These are the type names, not the name of the adapter used.
    var builtinAdapterTypes: Set<String> { get }
    
    func queryTypeName(input: String, output: String) -> String
    
    func typeName(for type: GenerationType) -> String
    
    func builtinType(named type: Substring) -> String
    
    /// A file source code containing all of the generated tables, queries and migrations.
    func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])],
        adapters: [AdapterReference]
    ) throws -> String
    
    /// Function to generate a interpolation segment in a string
    /// that contains the code to generate question marks for a
    /// parameter with the given name.
    ///
    /// Example:
    /// ```swift
    /// \(input.sqlQuestionMarks)
    /// ```
    func interpolatedQuestionMarks(for param: String) -> String
}

extension Language {
    public func generate(
        migrations: [String],
        queries: [(String?, [Statement])],
        schema: Schema
    ) throws -> String {
        let values = try assemble(queries: queries, schema: schema)
        return try file(
            migrations: migrations,
            tables: values.tables,
            queries: values.queries,
            adapters: values.adapters
        )
    }
    
    public func assemble(
        queries: [(String?, [Statement])],
        schema: Schema
    ) throws -> (
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])],
        adapters: [AdapterReference]
    ) {
        let tables = Dictionary(schema.tables.map { ($0.key.name, model(for: $0.value)) }, uniquingKeysWith: { $1 })
        let queries = queries.map { ($0.map { "\($0)Queries" }, $1.map { query(for: $0, tables: tables) }) }
        
        let builtinAdapters = builtinAdapterTypes
            .map { adapterReference(name: $0, typeName: $0) }
        
        // Get a list of all adapters used. Right now we only have to look at the
        // tables since any output would inhereit the encoding of the source table.
        let adapters: Set<AdapterReference> = tables.reduce(into: []) { adapters, table in
            for field in table.value.fields.values {
                guard let adapter = field.type.adapter else { continue }
                adapters.insert(adapter)
            }
        }
        
        return (
            tables.values.sorted{ $0.name < $1.name },
            queries,
            adapters.subtracting(builtinAdapters).sorted{ $0.name < $1.name }
        )
    }
    
    private func query(
        for statement: Statement,
        tables: [Substring: GeneratedModel]
    ) -> GeneratedQuery {
        guard let definition = statement.definition else {
            fatalError("Upstream error should have caught this")
        }
        
        let input = inputTypeIfNeeded(statement: statement, definition: definition)
        let output = outputTypeIfNeeded(statement: statement, definition: definition, tables: tables)
        
        // Join the source segments together inserting the code to assemble the
        // question marks for any input.
        let sql = statement.sourceSegments.map { segment in
            switch segment {
            case let .text(text):
                return text.description
            case let .rowParam(param):
                let qs = interpolatedQuestionMarks(
                    for: statement.parameters.count > 1 ? "input.\(param.name)" : "input"
                )
                return "(\(qs))"
            }
        }.joined()
        
        let inputTypeName = typeName(for: input)
        let outputTypeName = typeName(for: output)
        
        return GeneratedQuery(
            name: definition.name.description,
            variableName: definition.name.lowercaseFirst,
            typeName: queryTypeName(input: inputTypeName, output: outputTypeName),
            typealiasName: "\(definition.name.capitalizedFirst)Query",
            input: input,
            inputName: inputTypeName,
            output: output,
            outputName: outputTypeName,
            outputCardinality: statement.outputCardinality,
            sourceSql: sql,
            isReadOnly: statement.isReadOnly,
            usedTableNames: statement.usedTableNames.sorted(),
            bindings: bindings(for: input)
        )
    }
    
    private func bindings(
        for input: GenerationType,
        name: String? = nil,
        owner: String? = nil,
        isOptional: Bool = false
    ) -> [GeneratedQuery.Binding] {
        var result: [GeneratedQuery.Binding] = []
        
        switch input {
        case .void:
            break
        case .builtin:
            result.append(.value(name: name ?? "input", owner: owner, isOptional: isOptional))
        case let .optional(type):
            result.append(
                contentsOf: bindings(
                    for: type,
                    name: name,
                    owner: owner,
                    isOptional: isOptional
                )
            )
        case .model(let model):
            for field in model.fields.values {
                result.append(
                    contentsOf: bindings(
                        for: field.type,
                        name: field.name,
                        owner: "input",
                        isOptional: isOptional
                    )
                )
            }
        case .array(let values):
            result.append(.arrayStart(name: name ?? "input", owner: owner, elementName: "element"))
            result.append(contentsOf: bindings(for: values, name: "element"))
            result.append(.arrayEnd)
        case .encoded(let storage, _, let adapter):
            result.append(
                .value(
                    name: name ?? "input",
                    owner: owner,
                    isOptional: isOptional,
                    adapter: (adapter, typeName(for: storage))
                )
            )
        }
        
        return result
    }
    
    private func model(for table: Table) -> GeneratedModel {
        GeneratedModel(
            name: table.name.name.capitalizedFirst,
            fields: table.columns.reduce(into: [:]) { fields, column in
                let name = column.key.description
                let type = column.value.type
                fields[name] = field(named: name, with: type)
            },
            isTable: true,
            nonOptionalIndices: table.columns.enumerated()
                .compactMap { (index, value) in
                    guard !value.value.type.isOptional else { return nil }
                    return index
                }
        )
    }
    
    private func generationType(for type: Type) -> GenerationType {
        switch type {
        case let .nominal(name):
            return .builtin(builtinType(named: name))
        case let .alias(root, alias, adapter):
            let alias = switch alias {
            case .explicit(let e): e.description
            case .hint(let hint):
                switch hint {
                case .bool: boolName
                }
            }
            
            return .encoded(
                generationType(for: root),
                alias: alias,
                adapter: adapterReference(name: adapter?.description ?? alias, typeName: alias)
            )
        case let .optional(type):
            return .optional(generationType(for: type))
        case let .row(.unknown(type)):
            return .array(generationType(for: type))
        case .error, .fn, .row(.fixed), .var:
            fatalError("Upstream error not caught")
        }
    }
    
    private func field(named name: String, with type: Type) -> GeneratedField {
        let type = generationType(for: type)
        return GeneratedField(name: name, type: type, typeName: typeName(for: type))
    }

    private func inputTypeIfNeeded(
        statement: Statement,
        definition: Definition
    ) -> GenerationType {
        guard let firstParameter = statement.parameters.first else { return .void }
        
        guard statement.parameters.count > 1 else {
            return generationType(for: firstParameter.type)
        }
        
        let inputTypeName = definition.input?.description ?? "\(definition.name.capitalizedFirst)Input"
        
        let model = GeneratedModel(
            name: inputTypeName,
            fields: statement.parameters.reduce(into: [:]) { fields, parameter in
                fields[parameter.name] = field(named: parameter.name, with: parameter.type)
            },
            isTable: false,
            nonOptionalIndices: []
        )
        
        return .model(model)
    }
    
    private func outputTypeIfNeeded(
        statement: Statement,
        definition: Definition,
        tables: [Substring: GeneratedModel]
    ) -> GenerationType {
        guard let firstResultColumns = statement.resultColumns.chunks.first else { return .void }
        
        // Will return an array if it returns many or optional if its a single result
        let singleOrMany: (GenerationType) -> GenerationType = {
            switch statement.outputCardinality {
            // INSERTs will always return a value so no need to do optional
            case .single: statement.isInsert ? $0 : .optional($0)
            case .many: .array($0)
            }
        }
        
        // Output can be mapped to a table struct
        if statement.resultColumns.chunks.count == 1,
           let tableName = firstResultColumns.table,
           let table = tables[tableName]
        {
            return singleOrMany(.model(table))
        }
        
        // Make sure there is at least one column else return void
        guard let firstColumn = firstResultColumns.columns.values.first?.type else {
            return .void
        }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.count > 1 else {
            return singleOrMany(generationType(for: firstColumn))
        }
        
        let outputTypeName = definition.output?.description ?? "\(definition.name.capitalizedFirst)Output"
        
        let model = GeneratedModel(
            name: outputTypeName,
            fields: statement.resultColumns.chunks.reduce(into: [:]) { fields, chunk in
                if let tableName = chunk.table, let table = tables[tableName] {
                    let name = tableName.description
                    let type: GenerationType = chunk.isTableOptional ? .optional(.model(table)) : .model(table)
                    fields[name] = GeneratedField(
                        name: name,
                        type: type,
                        typeName: typeName(for: type)
                    )
                } else {
                    for column in chunk.columns {
                        let name = column.key.description
                        let type = generationType(for: column.value.type)
                        fields[name] = GeneratedField(
                            name: name,
                            type: type,
                            typeName: typeName(for: type)
                        )
                    }
                }
            },
            isTable: false,
            nonOptionalIndices: []
        )
        
        return singleOrMany(.model(model))
    }
    
    /// Converts a type name to the usable adapter name. Basically lower camelcases it.
    ///
    /// Int -> int
    /// UUID -> uuid
    /// Foo.ID -> fooID
    private func adapterReference(name: String, typeName: String) -> AdapterReference {
        var result = ""
        result.reserveCapacity(name.count)
        
        // Right now we only support Swift so we are expecting the input
        // to be upper camel case so we really only have to worry about
        // lower casing the initial characters until we hit the first lower
        // cased character
        var hasHitLowerCase = false
        
        for c in name {
            guard identifierCharacters.contains(c) else { continue }
            
            if !hasHitLowerCase {
                result.append(c.lowercased())
            } else {
                result.append(c)
            }
            
            hasHitLowerCase = hasHitLowerCase || c.isLowercase
        }
        
        return AdapterReference(name: result, type: typeName)
    }
}

let identifierCharacters: Set<Character> = {
    var characters: Set<Character> = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890_")
    characters.insert("_")
    return characters
}()

public struct GenerationOptions: Sendable {
    public var databaseName: String
    public var imports: [String]
    public var createDirectoryIfNeeded: Bool
    
    public init(
        databaseName: String,
        imports: [String] = [],
        createDirectoryIfNeeded: Bool = true
    ) {
        self.databaseName = databaseName
        self.imports = imports
        self.createDirectoryIfNeeded = createDirectoryIfNeeded
    }
}

public struct GeneratedModel: Equatable {
    let name: String
    let fields: OrderedDictionary<String, GeneratedField>
    /// Whether or not this was generated for a table
    let isTable: Bool
    let nonOptionalIndices: [Int]
    /// Whether this model can be decoded with the adapters or not
    let requiresAdapters: Bool
    
    init(
        name: String,
        fields: OrderedDictionary<String, GeneratedField>,
        isTable: Bool,
        nonOptionalIndices: [Int]
    ) {
        self.name = name
        self.fields = fields
        self.isTable = isTable
        self.nonOptionalIndices = nonOptionalIndices
        self.requiresAdapters = fields.contains{ $0.value.type.requiresAdapters }
    }
}

public struct GeneratedField: Equatable {
    /// The column name
    let name: String
    /// The type of the field.
    /// If it is a `model` that means the user selected
    /// all columns from a table `foo.*`
    let type: GenerationType
    /// The types name to use in the codegen.
    /// The name is accessed many times so we can just calculate
    /// it once and reuse it.
    let typeName: String
    
    /// Whether this type can be decoded with an adapter or not
    var requiresAdapter: Bool {
        return type.adapter != nil
    }
}

public struct GeneratedQuery {
    let name: String
    let variableName: String
    let typeName: String
    let typealiasName: String
    let input: GenerationType
    let inputName: String
    let output: GenerationType
    let outputName: String
    let outputCardinality: Cardinality
    let sourceSql: String
    let isReadOnly: Bool
    let usedTableNames: [Substring]
    let bindings: [Binding]
    
    public enum Binding {
        case value(
            name: String,
            owner: String? = nil,
            isOptional: Bool = false,
            adapter: (adapter: AdapterReference, storage: String)? = nil
        )
        case arrayStart(name: String, owner: String?, elementName: String)
        case arrayEnd
    }
}

public enum GenerationType: Equatable {
    case void
    case builtin(String)
    case model(GeneratedModel)
    indirect case optional(Self)
    indirect case array(Self)
    indirect case encoded(Self, alias: String, adapter: AdapterReference)
    
    var model: GeneratedModel? {
        switch self {
        case .void, .builtin: nil
        case .model(let model): model
        case .optional(let optional): optional.model
        case .array(let array): array.model
        case .encoded(let encoded, _, _): encoded.model
        }
    }
    
    var adapter: AdapterReference? {
        switch self {
        case .void, .builtin, .model: nil
        case .optional(let optional): optional.adapter
        case .array(let array): array.adapter
        case .encoded(_, _, let adapter): adapter
        }
    }
    
    var requiresAdapters: Bool {
        switch self {
        case .void, .builtin: false
        case .optional(let optional): optional.requiresAdapters
        case .array(let array): array.requiresAdapters
        case .encoded: true
        case .model(let model): model.requiresAdapters
        }
    }
}

public struct AdapterReference: Hashable {
    let name: String
    let type: String
}

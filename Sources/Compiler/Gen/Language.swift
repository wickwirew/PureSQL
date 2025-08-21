//
//  Language.swift
//  Otter
//
//  Created by Wes Wickwire on 4/28/25.
//

import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder

public protocol Language {
    init(options: GenerationOptions)
    
    var boolName: String { get }
    
    var builtinAdapters: Set<String> { get }
    
    func queryTypeName(input: String, output: String) -> String
    
    func typeName(for type: GenerationType) -> String
    
    func builtinType(named type: Substring) -> String
    
    /// A file source code containing all of the generated tables, queries and migrations.
    func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])],
        adapters: [String]
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
        
        // Get a list of all adapters used. Right now we only have to look at the
        // tables since any output would inhereit the encoding of the source table.
        let adapters: Set<String> = values.tables.reduce(into: []) { adapters, table in
            for field in table.fields.values {
                guard let adapter = field.type.adapter else { continue }
                adapters.insert(adapter)
            }
        }
        
        return try file(
            migrations: migrations,
            tables: values.tables,
            queries: values.queries,
            adapters: adapters.subtracting(builtinAdapters).sorted()
        )
    }
    
    public func assemble(
        queries: [(String?, [Statement])],
        schema: Schema
    ) throws -> (
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])]
    ) {
        let tables = Dictionary(schema.tables.map { ($0.key.name, model(for: $0.value)) }, uniquingKeysWith: { $1 })
        let queries = queries.map { ($0.map { "\($0)Queries" }, $1.map { query(for: $0, tables: tables) }) }
        return (tables.values.sorted{ $0.name < $1.name }, queries)
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
                    for: statement.parameters.count > 1 ? param.name : "input"
                )
                return "(\(qs))"
            }
        }.joined()
        
        let inputTypeName = typeName(for: input)
        let outputTypeName = typeName(for: output)
        var startIndex = 1
        
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
            bindings: bindings(for: input, index: &startIndex)
        )
    }
    
    private func bindings(
        for input: GenerationType,
        index: inout Int,
        name: String? = nil,
        owner: String? = nil,
        isOptional: Bool = false
    ) -> [GeneratedQuery.Binding] {
        var result: [GeneratedQuery.Binding] = []
        
        switch input {
        case .void:
            break
        case .builtin:
            result.append(.value(index: index, name: name ?? "input", owner: owner, isOptional: isOptional))
            index += 1
        case let .optional(type):
            result.append(
                contentsOf: bindings(
                    for: type,
                    index: &index,
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
                        index: &index,
                        name: field.name,
                        owner: "input",
                        isOptional: isOptional
                    )
                )
            }
        case .array(let values):
            result.append(.arrayStart(name: name ?? "input", elementName: "element"))
            result.append(contentsOf: bindings(for: values, index: &index, owner: "element"))
            result.append(.arrayEnd)
        case .encoded(let storage, _, let adapter):
            result.append(
                .value(
                    index: index,
                    name: name ?? "input",
                    owner: owner,
                    isOptional: isOptional,
                    adapter: (adapter, typeName(for: storage))
                )
            )
            index += 1
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
                adapter: "\(adapter?.description ?? alias)DatabaseValueAdapter"
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
}

public struct GenerationOptions: Sendable {
    public var databaseName: String
    public var imports: [String]
    public var createDirectoryIfNeeded: Bool
    
    public init(
        databaseName: String,
        imports: [String] = [],
        createDirectoryIfNeeded: Bool
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
            index: Int,
            name: String,
            owner: String? = nil,
            isOptional: Bool = false,
            adapter: (name: String, storage: String)? = nil
        )
        case arrayStart(name: String, elementName: String)
        case arrayEnd
    }
}

public enum GenerationType: Equatable {
    case void
    case builtin(String)
    case model(GeneratedModel)
    indirect case optional(Self)
    indirect case array(Self)
    indirect case encoded(Self, alias: String, adapter: String)
    
    var model: GeneratedModel? {
        switch self {
        case .void, .builtin: nil
        case .model(let model): model
        case .optional(let optional): optional.model
        case .array(let array): array.model
        case .encoded(let encoded, _, _): encoded.model
        }
    }
    
    var adapter: String? {
        switch self {
        case .void, .builtin, .model: nil
        case .optional(let optional): optional.adapter
        case .array(let array): array.adapter
        case .encoded(_, _, let adapter): adapter
        }
    }
}

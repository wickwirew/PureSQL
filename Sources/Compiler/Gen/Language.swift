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
    
    func queryTypeName(input: String, output: String) -> String
    
    func inputTypeName(input: BuiltinOrGenerated?) -> String
    
    func outputTypeName(
        output: BuiltinOrGenerated?,
        cardinality: Cardinality
    ) -> String
    
    /// Returns the Language builtin for the given SQL type
    func builtinType(for type: Type) -> String
    
    /// A file source code containing all of the generated tables, queries and migrations.
    func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])]
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
            queries: values.queries
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
        
        let inputTypeName = inputTypeName(input: input)
        let outputTypeName = outputTypeName(output: output, cardinality: statement.outputCardinality)
        
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
            usedTableNames: statement.usedTableNames.sorted()
        )
    }
    
    private func model(for table: Table) -> GeneratedModel {
        GeneratedModel(
            name: table.name.name.capitalizedFirst,
            fields: table.columns.reduce(into: [:]) { fields, column in
                let name = column.key.description
                let type = column.value.type
                fields[name] = GeneratedField(
                    name: name,
                    type: .builtin(
                        builtinType(for: type),
                        isArray: false,
                        encodedAs: builtinForAliasedType(for: type)
                    ),
                    isArray: type.isRow
                )
            },
            isTable: true,
            nonOptionalIndices: table.columns.enumerated()
                .compactMap { (index, value) in
                    guard !value.value.type.isOptional else { return nil }
                    return index
                }
        )
    }
    
    /// If the column type was aliased then this will return the `builtin`
    /// type for the root type of the alias.
    private func builtinForAliasedType(for type: Type) -> String? {
        guard case let .alias(root, _) = type else { return nil }
        return builtinType(for: root)
    }
    
    private func inputTypeIfNeeded(
        statement: Statement,
        definition: Definition
    ) -> BuiltinOrGenerated? {
        guard let firstParameter = statement.parameters.first else { return nil }
        
        guard statement.parameters.count > 1 else {
            return .builtin(
                builtinType(for: firstParameter.type),
                isArray: firstParameter.type.isRow,
                encodedAs: builtinForAliasedType(for: firstParameter.type)
            )
        }
        
        let inputTypeName = definition.input?.description ?? "\(definition.name.capitalizedFirst)Input"
        
        let model = GeneratedModel(
            name: inputTypeName,
            fields: statement.parameters.reduce(into: [:]) { fields, parameter in
                fields[parameter.name] = GeneratedField(
                    name: parameter.name,
                    type: .builtin(
                        builtinType(for: parameter.type),
                        isArray: false,
                        encodedAs: builtinForAliasedType(for: parameter.type)
                    ),
                    isArray: parameter.type.isRow
                )
            },
            isTable: false,
            nonOptionalIndices: []
        )
        
        return .model(model, isOptional: false)
    }
    
    private func outputTypeIfNeeded(
        statement: Statement,
        definition: Definition,
        tables: [Substring: GeneratedModel]
    ) -> BuiltinOrGenerated? {
        guard let firstResultColumns = statement.resultColumns.chunks.first else { return nil }
        
        // Output can be mapped to a table struct
        if statement.resultColumns.chunks.count == 1,
           let tableName = firstResultColumns.table,
           let table = tables[tableName]
        {
            return .model(table, isOptional: false)
        }
        
        // Make sure there is at least one column else return void
        guard let firstColumn = firstResultColumns.columns.values.first?.type else {
            return nil
        }
        
        // Only one column returned, just use it's type
        guard statement.resultColumns.count > 1 else {
            return .builtin(
                builtinType(for: firstColumn),
                isArray: firstColumn.isRow,
                encodedAs: builtinForAliasedType(for: firstColumn)
            )
        }
        
        let outputTypeName = definition.output?.description ?? "\(definition.name.capitalizedFirst)Output"
        
        let model = GeneratedModel(
            name: outputTypeName,
            fields: statement.resultColumns.chunks.reduce(into: [:]) { fields, chunk in
                if let tableName = chunk.table, let table = tables[tableName] {
                    let name = tableName.description
                    fields[name] = GeneratedField(
                        name: name,
                        type: .model(table, isOptional: chunk.isTableOptional),
                        isArray: false
                    )
                } else {
                    for column in chunk.columns {
                        let name = column.key.description
                        let type = column.value.type
                        fields[name] = GeneratedField(
                            name: name,
                            type: .builtin(
                                builtinType(for: type),
                                isArray: false,
                                encodedAs: builtinForAliasedType(for: type)
                            ),
                            isArray: type.isRow
                        )
                    }
                }
            },
            isTable: false,
            nonOptionalIndices: []
        )
        
        return .model(model, isOptional: false)
    }
}

public struct GenerationOptions: Sendable {
    public var databaseName: String
    public var imports: [String]
    
    public init(
        databaseName: String? = nil,
        imports: [String] = []
    ) {
        self.databaseName = databaseName ?? "DB"
        self.imports = imports
    }
}

public struct GeneratedModel {
    let name: String
    let fields: OrderedDictionary<String, GeneratedField>
    /// Whether or not this was generated for a table
    let isTable: Bool
    let nonOptionalIndices: [Int]
}

public struct GeneratedField {
    /// The column name
    let name: String
    /// The type of the field.
    /// If it is a `model` that means the user selected
    /// all columns from a table `foo.*`
    let type: BuiltinOrGenerated
    /// Whether or not it is an array. Some fields can take a list
    /// as an input for a query like `foo IN :bar`
    let isArray: Bool
    
    /// The underlying storage type if it is aliased
    var encodedAsType: String? {
        guard case let .builtin(_, _, encodedAs) = type else { return nil }
        return encodedAs
    }
}

public struct GeneratedQuery {
    let name: String
    let variableName: String
    let typeName: String
    let typealiasName: String
    let input: BuiltinOrGenerated?
    let inputName: String
    let output: BuiltinOrGenerated?
    let outputName: String
    let outputCardinality: Cardinality
    let sourceSql: String
    let isReadOnly: Bool
    let usedTableNames: [Substring]
}

public enum BuiltinOrGenerated: CustomStringConvertible {
    /// Types can be aliased. So `TEXT AS UUID`. `encodedAs`
    /// would be the `TEXT`. It will allow us to tell the
    /// `bind` functions to actually encode to the underlying
    /// type rather than just having `UUID` always go to `TEXT`
    /// when some users may want a `BLOB`.
    case builtin(String, isArray: Bool, encodedAs: String?)
    case model(GeneratedModel, isOptional: Bool)
    
    public var description: String {
        switch self {
        case let .builtin(builtin, isArray, _):
            isArray ? "[\(builtin)]" : builtin
        case let .model(model, isOptional):
            isOptional ? "\(model.name)?" : model.name
        }
    }
}

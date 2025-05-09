//
//  Language.swift
//  Feather
//
//  Created by Wes Wickwire on 4/28/25.
//

import OrderedCollections
import SwiftSyntax
import SwiftSyntaxBuilder

public protocol Language {
    /// Returns the Language builtin for the given SQL type
    static func builtinType(for type: Type) -> String
    
    /// The query type name with the given cardinality, input and output
    static func queryType(
        for cardinality: Cardinality?,
        input: BuiltinOrGenerated?,
        output: BuiltinOrGenerated?
    ) -> String
    
    /// A file source code containing all of the generated tables, queries and migrations.
    static func file(
        databaseName: String,
        migrations: [String],
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        options: GenerationOptions
    ) throws -> String
    
    /// Function to generate a interpolation segment in a string
    /// that contains the code to generate question marks for a
    /// parameter with the given name.
    ///
    /// Example:
    /// ```swift
    /// \(input.sqlQuestionMarks)
    /// ```
    static func interpolatedQuestionMarks(for param: String) -> String
}

extension Language {
    public static func generate(
        databaseName: String,
        migrations: [String],
        queries: [Statement],
        schema: Schema,
        options: GenerationOptions
    ) throws -> String {
        let tables = schema.mapValues(model(for:))
        let queries = queries.map { query(for: $0, tables: tables) }
        
        return try file(
            databaseName: databaseName,
            migrations: migrations,
            tables: Array(tables.values),
            queries: queries,
            options: options
        )
    }
    
    private static func query(
        for statement: Statement,
        tables: OrderedDictionary<Substring, GeneratedModel>
    ) -> GeneratedQuery {
        guard let definition = statement.definition else {
            fatalError("Upstream error should have caught this")
        }
        
        let input = inputTypeIfNeeded(statement: statement, definition: definition)
        let output = outputTypeIfNeeded(statement: statement, definition: definition, tables: tables)
        
        let type = queryType(
            for: statement.noOutput ? nil : statement.outputCardinality,
            input: input,
            output: output
        )
        
        // Join the source segments together inserting the code to assemble the
        // question marks for any input.
        let sql = statement.sourceSegments.map { segment in
            switch segment {
            case .text(let text):
                return text.description
            case .rowParam(let param):
                return interpolatedQuestionMarks(
                    for: statement.parameters.count > 1 ? param.name : "input"
                )
            }
        }.joined()
        
        return GeneratedQuery(
            name: "\(definition.name)Query",
            type: type,
            input: input,
            output: output,
            outputCardinality: statement.outputCardinality,
            sourceSql: sql,
            isReadOnly: statement.isReadOnly
        )
    }
    
    private static func model(for table: Table) -> GeneratedModel {
        GeneratedModel(
            name: table.name.capitalizedFirst,
            fields: table.columns.reduce(into: [:]) { fields, column in
                let name = column.key.description
                let type = column.value
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
            isTable: true
        )
    }
    
    /// If the column type was aliased then this will return the `builtin`
    /// type for the root type of the alias.
    private static func builtinForAliasedType(for type: Type) -> String? {
        guard case let .alias(root, _) = type else { return nil }
        return builtinType(for: root)
    }
    
    private static func inputTypeIfNeeded(
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
            isTable: false
        )
        
        return .model(model)
    }
    
    private static func outputTypeIfNeeded(
        statement: Statement,
        definition: Definition,
        tables: OrderedDictionary<Substring, GeneratedModel>
    ) -> BuiltinOrGenerated? {
        guard let firstResultColumns = statement.resultColumns.chunks.first else { return nil }
        
        // Output can be mapped to a table struct
        if statement.resultColumns.chunks.count == 1,
           let tableName = firstResultColumns.table,
            let table = tables[tableName] {
            return .model(table)
        }
        
        // Make sure there is at least one column else return void
        guard let firstColumn = firstResultColumns.columns.values.first else {
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
                        type: .model(table),
                        isArray: false
                    )
                } else {
                    for column in chunk.columns {
                        let name = column.key.description
                        let type = column.value
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
            isTable: false
        )
        
        return .model(model)
    }
}


public typealias GenerationOptions = Set<GenerationOption>

public enum GenerationOption: Hashable {
    case namespaceGeneratedModels
}

public struct GeneratedModel {
    let name: String
    let fields: OrderedDictionary<String, GeneratedField>
    /// Whether or not this was generated for a table
    let isTable: Bool
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
    let type: String
    let input: BuiltinOrGenerated?
    let output: BuiltinOrGenerated?
    let outputCardinality: Cardinality
    let sourceSql: String
    let isReadOnly: Bool
}

public struct GeneratedResult<Decl> {
    let queries: [Decl]
    let inputs: [Decl]
    let outputs: [Decl]
}

public enum BuiltinOrGenerated: CustomStringConvertible {
    /// Types can be aliased. So `TEXT AS UUID`. `encodedAs`
    /// would be the `TEXT`. It will allow us to tell the
    /// `bind` functions to actually encode to the underlying
    /// type rather than just having `UUID` always go to `TEXT`
    /// when some users may want a `BLOB`.
    case builtin(String, isArray: Bool, encodedAs: String?)
    case model(GeneratedModel)
    
    public var description: String {
        switch self {
        case .builtin(let builtin, let isArray, _):
            isArray ? "[\(builtin)]" : builtin
        case .model(let model):
            model.name
        }
    }
    
    public func namespaced(to namespace: String) -> String {
        switch self {
        case .model(let model) where !model.isTable: "\(namespace).\(self)"
        default: description
        }
    }
}

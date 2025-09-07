//
//  SwiftLanguage.swift
//  Otter
//
//  Created by Wes Wickwire on 6/8/25.
//

public struct SwiftLanguage: Language {
    let options: GenerationOptions
    private var writer = SourceWriter()
    
    public init(options: GenerationOptions) {
        self.options = options
    }
    
    public var boolName: String { "Bool" }
    
    public var builtinAdapterTypes: Set<String> {
        [
            "Bool",
            "Int8",
            "Int16",
            "Int32",
            "Int64",
            "UInt8",
            "UInt16",
            "UInt32",
            "UInt64",
            "UInt",
            "Float",
            "Float16",
            "UUID",
            "Decimal",
            "Date",
            "URL",
        ]
    }
    
    public func queryTypeName(
        input: String,
        output: String
    ) -> String {
        return "DatabaseQuery<\(input), \(output)>"
    }
    
    public func interpolatedQuestionMarks(for param: String) -> String {
        return "\\(\(param).sqlQuestionMarks)"
    }
    
    public func typeName(for type: GenerationType) -> String {
        switch type {
        case .void: "()"
        case .builtin(let builtin): builtin
        case .model(let model): model.name
        case .optional(let type): "\(typeName(for: type))?"
        case .array(let type): "[\(typeName(for: type))]"
        case .encoded(_, let alias, _): alias
        }
    }
    
    public func builtinType(named type: Substring) -> String {
        switch type {
        case "REAL": "Double"
        case "INT": "Int"
        case "INTEGER": "Int"
        case "TEXT": "String"
        case "BLOB": "Data"
        default: "SQLAny"
        }
    }
    
    public func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])],
        adapters: [AdapterReference]
    ) throws -> String {
        // Note: For now just going to ignore the `adapters`
        // Kotlin will need that info which is why it exists.
        // Swift having less finegrained namespaces makes it
        // so it can just do module level lookups for the type.
        // where kotlin defining it just in the project isnt enough
        // cause it will be in a different namespace.
        //
        // Swift we may want to improve it. This is a good starting point though.
        
        let allQueries = queries.flatMap(\.1)
        
        writer.write("import Foundation")
        writer.write(line: "import Otter")
        
        for `import` in options.imports {
            writer.write(line: "import \(`import`)")
        }
        
        writer.blankLine()
        
        for table in tables {
            declaration(for: table, isOutput: true)
        }
        
        for query in allQueries {
            modelsFor(query: query)
        }
        
        for (namespace, queries) in queries {
            if let namespace {
                self.queries(name: namespace, queries: queries)
            }
        }
        
        dbStruct(queries: queries, migrations: migrations, adapters: adapters)
        writer.blankLine()
        
        for query in allQueries {
            typeAlias(for: query)
            
            if let model = query.input.model {
                inputExtension(for: query, input: model)
            }
        }
        
        return writer.description
    }
    
    /// Called by the actual Swift macro since it doesnt generate an entire
    /// file and requires a little extra treatment
    public func macro(
        databaseName: String,
        migrations: [String],
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        addConnection: Bool,
        adapters: [AdapterReference]
    ) -> [String] {
        var decls: [String] = []
        
        // SwiftSyntax wants each decl in its own string
        // so we will just break it up.
        func take() {
            decls.append(writer.description)
            writer.reset()
        }
        
        writer.write("let connection: any Otter.Connection")
        take()
        self.adapters(adapters: adapters)
        take()
        
        writer.write("static var sanitizedMigrations: [String] ")
        writer.braces {
            writer.write(line: "return ")
            writer.brackets {
                for (position, migration) in migrations.positional() {
                    multilineStringLiteral(of: migration)
                    
                    if !position.isLast {
                        writer.write(",")
                    }
                }
            }
        }
        
        for table in tables {
            declaration(for: table, isOutput: true)
            take()
        }
        
        // Always do this at the top level since it will automatically namespaced under the
        // struct that the macro is attached too.
        for query in queries {
            modelsFor(query: query)
            take()
            declaration(for: query, underscoreName: true, databaseName: databaseName)
            take()
            typeAlias(for: query)
            take()
            dbTypeAlias(for: query)
            take()
        }
        
        return decls
    }
    
    private func dbStruct(
        queries: [(String?, [GeneratedQuery])],
        migrations: [String],
        adapters: [AdapterReference]
    ) {
        writer.write(line: "struct ", options.databaseName, ": Database")
        
        writer.braces {
            writer.write(line: "let connection: any Otter.Connection")
            self.adapters(adapters: adapters)
            
            writer.newline()
            
            writer.write(line: "static var migrations: [String] ")
            writer.braces {
                writer.write(line: "return ")
                writer.brackets {
                    for (position, migration) in migrations.positional() {
                        multilineStringLiteral(of: migration)
                        
                        if !position.isLast {
                            writer.write(",")
                        }
                    }
                }
            }
            
            for (namespace, queries) in queries {
                if let namespace {
                    writer.write(line: "var ", namespace.lowercaseFirst, ": ", namespace, " ")
                    
                    // Initialize queries object
                    writer.braces {
                        writer.write(line: namespace, ".live(connection: connection, adapters: adapters)")
                    }
                } else {
                    // Generate queries with `nil` namespace which would make it global.
                    // This is really only used by the macro since it doesnt have file names
                    // which really wont happen here but still implement it for completeness.
                    for query in queries {
                        declaration(for: query, databaseName: options.databaseName)
                    }
                }
            }
        }
    }
    
    private func adapters(adapters: [AdapterReference]) {
        writer.write(line: "let adapters: Adapters")
        writer.newline()
        
        if adapters.isEmpty {
            writer.write(line: "typealias Adapters = DefaultAdapters")
        } else {
            writer.write(line: "struct Adapters: Otter.Adapters ")
            writer.braces {
                for adapter in adapters {
                    writer.write(line: "let ", adapter.name, ": AnyDatabaseValueAdapter<", adapter.type, ">")
                }
                
                writer.blankLine()
                writer.write(line: "init(")
                writer.indented {
                    for (position, adapter) in adapters.positional() {
                        writer.write(line: adapter.name, ": any DatabaseValueAdapter<", adapter.type, ">")
                        
                        if !position.isLast {
                            writer.write(",")
                        }
                    }
                }
                writer.write(line: ") ")
                
                writer.braces {
                    for adapter in adapters {
                        writer.write(line: "self.", adapter.name, " = AnyDatabaseValueAdapter<", adapter.type, ">(", adapter.name, ")")
                    }
                }
            }
        }
    }
    
    private func queries(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "struct ", name, ": ConnectionWrapper, Sendable {")
        writer.indent()
        
        writer.write(line: "let connection: any Connection")
        
        for query in queries {
            writer.write(line: "var ", query.variableName, ": any ", query.typealiasName)
        }
        
        writer.blankLine()
        
        queriesNoop(name: name, queries: queries)
        queriesLive(name: name, queries: queries)
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func queriesLive(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "static func live(connection: Connection, adapters: DB.Adapters) -> ", name," {")
        writer.indent()
        
        writer.write(line: "return ", name, "(")
        writer.indent()
        
        writer.write(line: "connection: connection,")
        
        for (position, query) in queries.positional() {
            writer.write(line: query.variableName, ": ")
            
            expression(for: query)
            
            if !position.isLast {
                writer.write(",")
            }
        }
        
        writer.unindent()
        writer.write(line: ")")
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func queriesNoop(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "static func noop(")
        writer.indented {
            for (position, query) in queries.positional() {
                writer.write(line: query.variableName, ": any ", query.typealiasName, " = ")
                
                switch query.output {
                case .model:
                    // We might be able to initialize one in the future with all default values
                    // but it seems hacky so just fail
                    writer.write("Queries.Fail()")
                case .builtin(let name):
                    let defaultValue = switch name {
                    case "Double": "0.0"
                    case "Int": "0"
                    case "String": "\"\""
                    case "Data": "Data()"
                    default: "SQLAny.int(0)"
                    }
                    writer.write("Queries.Just(", defaultValue, ")")
                default:
                    writer.write("Queries.Just()")
                }
                
                if !position.isLast {
                    writer.write(",")
                }
            }
        }
        writer.write(line: ") -> ", name," {")
        
        writer.indent()
        
        writer.write(line: name, "(")
        writer.indent()
        
        writer.write(line: "connection: NoopConnection(),")
        
        for (position, query) in queries.positional() {
            writer.write(line: query.variableName, ": ", query.variableName)
            
            if !position.isLast {
                writer.write(",")
            }
        }
        
        writer.unindent()
        writer.write(line: ")")
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func expression(for query: GeneratedQuery) {
        writer.write(query.typeName)
        writer.write("(")
        
        writer.indented {
            writer.write(line: query.isReadOnly ? ".read," : ".write,")
            writer.write(line: "in: connection,")
            writer.write(line: "watchingTables: [")
            
            for (position, table) in query.usedTableNames.positional() {
                writer.write("\"", table, "\"")
                
                if !position.isLast {
                    writer.write(",")
                }
            }
            
            writer.write("]")
        }
        
        writer.write(line: ") { input, tx in")
        writer.indent()

        writer.write(line: "let statement = try Otter.Statement(")
        writer.indent()
        multilineStringLiteral(of: query.sourceSql)
        writer.write(",")
        writer.write(line: "transaction: tx")
        writer.unindent()
        writer.write(line: ")")
        
        for binding in query.bindings {
            bind(binding: binding)
        }
        
        if query.output == .void {
            writer.write(line: "_ = try statement.step()")
        } else {
            switch query.outputCardinality {
            case .single:
                writer.write(line: "return try statement.fetchOne(")
            case .many:
                writer.write(line: "return try statement.fetchAll(")
            }
            
            switch query.output {
            case .encoded(let storage, _, let adapter),
                .optional(.encoded(let storage, _, let adapter)),
                .array(.encoded(let storage, _, let adapter)):
                writer.write("adapter: adapters.", adapter.name, ", storage: ", typeName(for: storage), ".self")
                break
            case .model(let model),
                .optional(.model(let model)),
                .array(.model(let model)):
                if model.requiresAdapters {
                    writer.write("adapters: adapters")
                }
            default:
                break
            }
            
            writer.write(")")
        }
        
        writer.unindent()
        writer.write(line: "}")
    }
    
    private func declaration(
        for query: GeneratedQuery,
        underscoreName: Bool = false,
        databaseName: String
    ) {
        let variableName = underscoreName ? "_\(query.variableName)" : query.variableName
        writer.write("var ", variableName, ": ", query.typeName)
        writer.braces {
            expression(for: query)
        }
    }
    
    private func declaration(
        for model: GeneratedModel,
        isOutput: Bool
    ) {
        // All of the tables we need to add dynamic lookup on.
        // The last `Bool` is a flag for wether the embedded table
        // is optional or not.
        let dynamicLookupTables = model.fields.values
            .compactMap { value -> (String, GeneratedModel, Bool)? in
                switch value.type {
                case .model(let model):
                    return (value.name, model, false)
                case .optional(let type):
                    switch type {
                    case .model(let model):
                        return (value.name, model, true)
                    default:
                        return nil
                    }
                default:
                    return nil
                }
            }
        
        let addDynamicLookup = isOutput && !dynamicLookupTables.isEmpty && model.fields.count > 1
        
        if addDynamicLookup {
            writer.write(line: "@dynamicMemberLookup")
        }
        
        writer.write(line: "struct ", model.name, ": Hashable, Sendable")
        
        if model.fields["id"] != nil {
            writer.write(", Identifiable")
        }
        
        if isOutput {
            if model.requiresAdapters {
                writer.write(", RowDecodableWithAdapters")
            } else {
                writer.write(", RowDecodable")
            }
        }
        
        writer.write(" {")
        
        // Indent for start of variables
        writer.indent()
        
        // Write out fields of struct
        for field in model.fields.values {
            writer.write(line: "let ", field.name, ": ", field.typeName)
        }
        
        if isOutput {
            writer.blankLine()
            
            writer.write(line: "static let nonOptionalIndices: [Int32] = [")
            for (position, index) in model.nonOptionalIndices.positional() {
                writer.write(index.description)
                
                if !position.isLast {
                    writer.write(", ")
                }
            }
            writer.write("]")
            
            writer.blankLine()
            rowDecodableInit(for: model)
            writer.blankLine()
            memberWiseInit(for: model)
        }
        
        if addDynamicLookup {
            for (fieldName, table, isOptional) in dynamicLookupTables {
                dynamicMemberLookup(
                    fieldName: fieldName,
                    typeName: table.name,
                    isOptional: isOptional
                )
            }
        }
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func modelsFor(query: GeneratedQuery) {
        if let model = query.input.model, !model.isTable {
            declaration(for: model, isOutput: false)
        }
        
        if let model = query.output.model, !model.isTable {
            declaration(for: model, isOutput: true)
        }
    }
    
    private func dynamicMemberLookup(
        fieldName: String,
        typeName: String,
        isOptional: Bool
    ) {
        writer.newline()
        writer.write(line: "subscript<Value>(dynamicMember dynamicMember: ")
        writer.write("KeyPath<", typeName, ", Value>) -> Value")
        if isOptional {
            writer.write("?")
        }
        writer.write(" ")
        writer.braces {
            writer.write(line: "self.", fieldName)
            if isOptional {
                writer.write("?")
            }
            writer.write("[keyPath: dynamicMember]")
        }
    }
    
    private func rowDecodableInit(for model: GeneratedModel) {
        // Initializer signature
        writer.write(line: "init(")
        writer.indent()
        writer.write(line: "row: borrowing Otter.Row,")
        writer.write(line: "startingAt start: Int32")
        
        if model.requiresAdapters {
            writer.write(",")
            writer.write(line: "adapters: ", options.databaseName, ".Adapters")
        }
        
        writer.unindent()
        writer.write(line: ") throws(Otter.OtterError) {")
        
        writer.indent()
        var index = 0
        for field in model.fields.values {
            writer.write(line: "self.")
            writer.write(field.name)
            writer.write(" = try ")
            
            switch field.type {
            case .builtin, .optional(.builtin):
                writer.write("row.value(at: start + ", index.description, ")")
                index += 1
            case let .model(model):
                writer.write("row.embedded(at: start + ", index.description)
                if model.requiresAdapters {
                    writer.write(", adapters: adapters")
                }
                writer.write(")")
                index += model.fields.count
            case let .optional(.model(model)):
                writer.write("row.optionallyEmbedded(at: start + ", index.description)
                if model.requiresAdapters {
                    writer.write(", adapters: adapters")
                }
                writer.write(")")
                index += model.fields.count
            case let .encoded(storage, _, adapter):
                writer.write("row.value(at: start + ", index.description, ", using: adapters.", adapter.name, ", storage: ", typeName(for: storage), ".self)")
                index += 1
            case let .optional(.encoded(storage, _, adapter)):
                writer.write("row.optionalValue(at: start + ", index.description, ", using: adapters.", adapter.name, ", storage: ", typeName(for: storage), ".self)")
                index += 1
            default:
                fatalError("Invalid field type \(field.typeName) \(field.type)")
            }
        }
        writer.unindent()
        
        writer.write(line: "}")
    }
    
    private func memberWiseInit(
        for model: GeneratedModel
    ) {
        // Initializer signature
        writer.write(line: "init(")
        writer.indent()
        
        for (position, (name, field)) in model.fields.elements.positional() {
            writer.write(line: name, ": ", field.typeName)
            
            if !position.isLast {
                writer.write(",")
            }
        }
        
        writer.unindent()
        writer.write(line: ") {")
        
        writer.indent()
        for field in model.fields.values {
            writer.write(line: "self.", field.name, " = ", field.name)
        }
        writer.unindent()
        
        writer.write(line: "}")
    }
    
    /// Creates a type alias for the query so it can be referenced as an existential
    private func typeAlias(for query: GeneratedQuery) {
        writer.write(line: "typealias ", query.typealiasName, " = Query<", query.inputName, ", ", query.outputName, ">")
    }
    
    /// Used in the macros, to create a typealias for the database query since those need
    /// to be referenced explicitly in their decl.
    private func dbTypeAlias(for query: GeneratedQuery, queryType: String = "Query") {
        let name = query.typealiasName.replacingOccurrences(of: "Query", with: "DatabaseQuery")
        writer.write(line: "typealias ", name, " = DatabaseQuery<", query.inputName, ", ", query.outputName, ">")
    }
    
    private func inputExtension(
        for query: GeneratedQuery,
        input: GeneratedModel
    ) {
        let writeInput: () -> Void = {
            for (position, field) in input.fields.elements.positional() {
                writer.write(field.value.name, ": ", field.value.typeName)
                
                if !position.isLast {
                    writer.write(", ")
                }
            }
        }
        
        let initInput: () -> Void = {
            for (position, field) in input.fields.elements.positional() {
                writer.write(field.key, ": ", field.key)
                
                if !position.isLast {
                    writer.write(", ")
                }
            }
        }
        
        extensionOn("Query") {
            self.writer.write("Input == ", query.inputName)
        } builder: {
            // Execute no tx
            writer.write("func execute(")
            writeInput()
            writer.write(") async throws -> Output ")
            
            writer.braces {
                writer.write(line: "try await execute(", query.inputName, "(")
                initInput()
                writer.write("))")
            }
            
            // Execute with tx
            writer.blankLine()
            writer.write(line: "func execute(")
            writeInput()
            writer.write(", tx: borrowing Transaction) throws -> Output ")
            
            writer.braces {
                writer.write(line: "try execute(", query.inputName, "(")
                initInput()
                writer.write("), tx: tx)")
            }
            
            // Observe
            writer.blankLine()
            writer.write(line: "func observe(")
            writeInput()
            writer.write(") -> QueryStream<Output> ")
            
            writer.braces {
                writer.write(line: "observe(", query.inputName, "(")
                initInput()
                writer.write("))")
            }
        }
    }
    
    private func extensionOn(
        _ type: String,
        conformance: String? = nil,
        condition: (() -> Void)? = nil,
        builder: () -> Void
    ) {
        writer.write(line: "extension ", type)
        
        if let conformance {
            writer.write(": ", conformance)
        }
        
        writer.write(" ")
        
        if let condition {
            writer.write("where ")
            condition()
            writer.write(" ")
        }
        
        writer.braces {
            writer.blankLine()
            builder()
        }
        writer.blankLine()
    }
    
    private func multilineStringLiteral(of string: String) {
        writer.write(line: "\"\"\"")
        
        for line in string.split(separator: "\n") {
            writer.write(line: line)
        }
        
        writer.write(line: "\"\"\"")
    }
    
    private func bind(binding: GeneratedQuery.Binding) {
        switch binding {
        case let .value(index, name, owner, _, adapter):
            writer.write(line: "try statement.bind(value: ")
            
            if let owner {
                writer.write(owner, ".")
            }
            
            writer.write(name, ", to: ", index.description)
            
            if let adapter {
                writer.write(", using: adapters.", adapter.adapter.name, ", as: ", adapter.storage, ".self")
            }
            
            writer.write(")")
        case let .arrayStart(name, elementName):
            writer.write(line: "for ", elementName, " in ", name, " {")
            writer.indent()
        case .arrayEnd:
            writer.unindent()
            writer.write(line: "}")
        }
    }
}

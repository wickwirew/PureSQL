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
    
    public func queryTypeName(
        input: String,
        output: String
    ) -> String {
        return "AnyDatabaseQuery<\(input), \(output)>"
    }
    
    public func inputTypeName(input: BuiltinOrGenerated?) -> String {
        return input?.description ?? "()"
    }
    
    public func outputTypeName(
        output: BuiltinOrGenerated?,
        cardinality: Cardinality
    ) -> String {
        if let type = output?.description {
            return switch cardinality {
            case .single: "\(type)?"
            case .many: "[\(type)]"
            }
        } else {
            return "()"
        }
    }
    
    public func interpolatedQuestionMarks(for param: String) -> String {
        return  "\\(\(param).sqlQuestionMarks)"
    }
    
    public func builtinType(for type: Type) -> String {
        return switch type {
        case let .nominal(name):
            switch name.uppercased() {
            case "REAL": "Double"
            case "INT": "Int"
            case "INTEGER": "Int"
            case "TEXT": "String"
            case "BLOB": "Data"
            default: "SQLAny"
            }
        case let .optional(ty): "\(builtinType(for: ty))?"
        case let .row(.unknown(ty)): "\(builtinType(for: ty))"
        case .var, .fn, .row, .error: "Any"
        case let .alias(_, alias):
            switch alias {
            case let .explicit(type):
                type.description
            case let .hint(hint):
                switch hint {
                case .bool: "Bool"
                }
            }
        }
    }
    
    public func file(
        migrations: [String],
        tables: [GeneratedModel],
        queries: [(String?, [GeneratedQuery])]
    ) throws -> String {
        let allQueries = queries.flatMap(\.1)
        
        writer.write("import Foundation")
        writer.write(line: "import Otter")
        writer.blankLine()
        
        for `import` in options.imports {
            writer.write(line: "import \(`import`)")
        }
        
        for table in tables {
            declaration(for: table, isOutput: true)
        }
        
        for query in allQueries {
            modelsFor(query: query)
        }
        
        for (namespace, queries) in queries {
            if let namespace {
                queriesProtocol(name: namespace, queries: queries)
                queriesNoop(name: namespace, queries: queries)
                queriesImpl(name: namespace, queries: queries)
            }
        }
        
        dbStruct(queries: queries, migrations: migrations)
        writer.blankLine()
        
        for query in allQueries {
            typeAlias(for: query)
            
            if let input = query.input, case let .model(model) = input {
                inputExtension(for: query, input: model)
            }
        }
        
        return writer.description
    }
    
    /// Called by the actual Swift macro since it doesnt generate an entire
    /// file and requires a little extra treatment
    public func macro(
        databaseName: String,
        tables: [GeneratedModel],
        queries: [GeneratedQuery],
        addConnection: Bool
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
        migrations: [String]
    ) {
        writer.write(line: "struct ", options.databaseName, ": Database")
        
        writer.braces {
            writer.write(line: "let connection: any Otter.Connection")
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
                    writer.write(line: "var ", namespace.lowercaseFirst, ": ", namespace, "Impl ")
                    
                    // Initialize queries object
                    writer.braces {
                        writer.write(line: namespace, "Impl", "(connection: connection)")
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
    
    private func queriesProtocol(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "protocol ", name, " {")
        
        writer.indent()
        
        for query in queries {
            let associatedType = query.name.capitalizedFirst
            writer.write(line: "associatedtype ", associatedType, ": ", query.typealiasName)
            writer.write(line: "var ", query.variableName, ": ", associatedType, " { get }")
        }
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func queriesNoop(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "struct ", name, "Noop: ", name, " {")
        writer.indent()
        
        for query in queries {
            writer.write(line: "let ")
            writer.write(query.variableName)
            writer.write(": AnyQuery<")
            writer.write(query.inputName)
            writer.write(", ")
            writer.write(query.outputName)
            writer.write(">")
        }
        
        writer.blankLine()
        writer.write(line: "init(")
        writer.indent()
        for (position, query) in queries.positional() {
            writer.write(line: query.variableName, ": any ", query.typealiasName, " = Queries.Just()")
            
            if !position.isLast {
                writer.write(",")
            }
        }
        writer.unindent()
        writer.write(line: ") {")
        writer.indent()
        
        for query in queries {
            writer.write(line: "self.", query.variableName, " = ", query.variableName, ".eraseToAnyQuery()")
        }
        
        writer.unindent()
        writer.write(line: "}")
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func queriesImpl(name: String, queries: [GeneratedQuery]) {
        writer.write(line: "struct ", name, "Impl: ", name, " {")
        writer.indent()
        
        writer.write(line: "let connection: any Connection")
        writer.blankLine()
        
        for (position, query) in queries.positional() {
            writer.write(line: "var ", query.variableName, ": ", query.typeName, " {")
            
            writer.indented {
                expression(for: query)
            }
            
            writer.write(line: "}")
            
            if !position.isLast {
                writer.newline()
            }
        }
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func expression(for query: GeneratedQuery) {
        writer.write(line: query.typeName)
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
        
        if query.input == nil {
            writer.write(line: "let")
        } else {
            writer.write(line: "var")
        }
        
        writer.write(" statement = try Otter.Statement(")
        writer.indent()
        multilineStringLiteral(of: query.sourceSql)
        writer.write(",")
        writer.write(line: "transaction: tx")
        writer.unindent()
        writer.write(line: ")")
        
        if let input = query.input {
            switch input {
            case let .builtin(_, isArray, encodedAs):
                bind(field: nil, encodeToType: encodedAs, isArray: isArray)
            case .model(let model):
                for field in model.fields.values {
                    bind(field: field.name, encodeToType: field.encodedAsType, isArray: field.isArray)
                }
            }
        }
        
        if query.output == nil {
            writer.write(line: "_ = try statement.step()")
        } else {
            switch query.outputCardinality {
            case .single:
                writer.write(line: "return try statement.fetchOne()")
            case .many:
                writer.write(line: "return try statement.fetchAll()")
            }
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
        let dynamicLookupTables = model.fields.values.compactMap { value -> (String, GeneratedModel)? in
            guard case let .model(model) = value.type else { return nil }
            return (value.name, model)
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
            writer.write(", RowDecodable")
        }
        
        writer.write(" {")
        
        // Indent for start of variables
        writer.indent()
        
        // Write out fields of struct
        for field in model.fields.values {
            writer.write(line: "let ", field.name, ": ", field.type.description)
        }
        
        if isOutput {
            writer.blankLine()
            rowDecodableInit(for: model)
            writer.blankLine()
            memberWiseInit(for: model)
        }
        
        if addDynamicLookup {
            for (fieldName, table) in dynamicLookupTables {
                dynamicMemberLookup(fieldName: fieldName, typeName: table.name)
            }
        }
        
        writer.unindent()
        writer.write(line: "}")
        writer.blankLine()
    }
    
    private func modelsFor(query: GeneratedQuery) {
        if case let .model(model) = query.input, !model.isTable {
            declaration(for: model, isOutput: false)
        }
        
        if case let .model(model) = query.output, !model.isTable {
            declaration(for: model, isOutput: true)
        }
    }
    
    private func dynamicMemberLookup(
        fieldName: String,
        typeName: String
    ) {
        writer.newline()
        writer.write(line: "subscript<Value>(dynamicMember dynamicMember: ")
        writer.write("KeyPath<", typeName, ", Value>) -> Value ")
        writer.braces {
            writer.write(line: "self.", fieldName, "[keyPath: dynamicMember]")
        }
    }
    
    private func rowDecodableInit(
        for model: GeneratedModel
    ) {
        // Initializer signature
        writer.write(line: "init(")
        writer.indent()
        writer.write(line: "row: borrowing Otter.Row,")
        writer.write(line: "startingAt start: Int32")
        writer.unindent()
        writer.write(line: ") throws(Otter.OtterError) {")
        
        writer.indent()
        var index = 0
        for field in model.fields.values {
            writer.write(line: "self.")
            writer.write(field.name)
            writer.write(" = try ")
            
            switch field.type {
            case .builtin(_, _, let encodedAs):
                if let encodedAs {
                    // Custom type
                    writer.write(field.type.description)
                    writer.write("(primitive: row.value(at: start + ")
                    writer.write(index.description)
                    writer.write(", as: ")
                    writer.write(encodedAs)
                    writer.write(".self))")
                } else {
                    // Decode primitive
                    writer.write("row.value(at: start + ", index.description, ")")
                }
                
                index += 1
            case .model(let model):
                // Model initializer
                writer.write(field.type.description, "(row: row, startingAt: start + ", index.description, ")")
                index += model.fields.count
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
            writer.write(line: name, ": ", field.type.description)
            
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
        writer.write(line: "typealias ", name, " = AnyDatabaseQuery<", query.inputName, ", ", query.outputName, ">")
    }
    
    private func inputExtension(
        for query: GeneratedQuery,
        input: GeneratedModel
    ) {
        extensionOn("Query") {
            self.writer.write("Input == ", query.inputName)
        } builder: {
            writer.write("func execute(")
            for (position, field) in input.fields.elements.positional() {
                writer.write(field.value.name, ": ", field.value.type.description)
                
                if !position.isLast {
                    writer.write(", ")
                }
            }
            
            writer.write(") async throws -> Output ")
            writer.braces {
                writer.write(line: "try await execute(with: ", query.inputName, "(")
                
                for (position, field) in input.fields.elements.positional() {
                    writer.write(field.key, ": ", field.key)
                    
                    if !position.isLast {
                        writer.write(", ")
                    }
                }
                
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
    
    private func bind(
        field: String?,
        encodeToType: String?,
        isArray: Bool
    ) {
        let paramName = field.map{ "input.\($0)" } ?? "input"
        let encode = encodeToType.map{ ".encodeTo\($0)()" } ?? ""
        
        if isArray {
            writer.write(line: "for element in ", paramName, " {")
            
            writer.indented {
                writer.write(line: "try statement.bind(value: element", encode, ")")
            }
            
            writer.write(line: "}")
        } else {
            writer.write(line: "try statement.bind(value: ", paramName, encode, ")")
        }
    }
}

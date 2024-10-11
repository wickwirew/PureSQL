
@freestanding(declaration, names: named(Schema))
public macro schema(_ source: [String: String]) = #externalMacro(module: "SQLMacros", type: "SchemaMacro")

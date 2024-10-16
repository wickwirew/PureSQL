
@freestanding(declaration, names: named(Schema))
public macro schema(_ source: [String: String]) = #externalMacro(module: "SQLMacros", type: "SchemaMacro")

@freestanding(expression)
public macro query(_ source: String) = #externalMacro(module: "SQLMacros", type: "QueryMacro")

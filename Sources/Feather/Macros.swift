
@freestanding(declaration, names: arbitrary)
public macro schema(_ source: [String: String]) = #externalMacro(module: "FeatherMacros", type: "SchemaMacro")

@freestanding(expression)
public macro query(_ source: String) = #externalMacro(module: "FeatherMacros", type: "QueryMacro")

@attached(member, names: arbitrary)
public macro Database() = #externalMacro(module: "FeatherMacros", type: "DatabaseMacro")

public protocol Database {
    static var queries: [String: String] { get }
    static var migrations: [String] { get }
}

@attached(member, names: arbitrary)
@attached(extension, conformances: Database)
public macro Database() = #externalMacro(module: "PureSQLMacros", type: "DatabaseMacro")

@attached(accessor)
public macro Query(
    _ source: String,
    inputName: String? = nil,
    oututName: String? = nil
) = #externalMacro(module: "PureSQLMacros", type: "QueryMacro")

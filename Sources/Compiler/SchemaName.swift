//
//  SchemaName.swift
//  Feather
//
//  Created by Wes Wickwire on 6/2/25.
//

/// The name of the schema. As of now only `main` and `temp`
/// are supported but if we supported external schemas we could
/// expand this later on.
public enum SchemaName: Hashable, Sendable {
    case main
    case temp
    
    init(isTemp: Bool) {
        self = isTemp ? .temp : .main
    }
    
    init?(_ name: Substring) {
        switch name {
        case "main": self = .main
        case "temp": self = .temp
        default: return nil
        }
    }
}

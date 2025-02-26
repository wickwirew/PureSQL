//
//  Checkable.swift
//  Feather
//
//  Created by Wes Wickwire on 2/25/25.
//

protocol Checkable: CustomReflectable {
    var typeName: String { get }
}

//
//  Ty.swift
//  
//
//  Created by Wes Wickwire on 10/8/24.
//

public enum Ty {
    case int
    case integer
    case tinyint
    case smallint
    case mediumint
    case bigint
    case unsignedBigInt
    case int2
    case int8
    case numeric
    case decimal(Int, Int)
    case boolean
    case date
    case datetime
    case real
    case double
    case doublePrecision
    case float
    case character(Int)
    case varchar(Int)
    case varyingCharacter(Int)
    case nchar(Int)
    case nativeCharacter(Int)
    case nvarchar(Int)
    case text
    case clob
    case blob
}

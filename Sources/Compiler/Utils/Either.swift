//
//  Either.swift
//  Otter
//
//  Created by Wes Wickwire on 6/7/25.
//

/// A type that can either be `First` or `Second`
enum Either<First, Second> {
    case first(First)
    case second(Second)
}

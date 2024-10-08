//
//  ParsingError.swift
//  
//
//  Created by Wes Wickwire on 10/8/24.
//

struct ParsingError: Error {
    let message: String
    let sourceRange: Range<String.Index>
}

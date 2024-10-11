//
//  Token.swift
//  
//
//  Created by Wes Wickwire on 10/8/24.
//

import Schema

struct Token {
    let kind: Kind
    let range: Range<String.Index>
    
    static let keywords: [String: Kind] = [
        .abort,
        .action,
        .add,
        .after,
        .all,
        .alter,
        .always,
        .analyze,
        .and,
        .as,
        .asc,
        .attach,
        .autoincrement,
        .before,
        .begin,
        .between,
        .by,
        .cascade,
        .case,
        .cast,
        .check,
        .collate,
        .column,
        .commit,
        .conflict,
        .constraint,
        .create,
        .cross,
        .current,
        .currentDate,
        .currentTime,
        .currentTimestamp,
        .database,
        .default,
        .deferrable,
        .deferred,
        .delete,
        .desc,
        .detach,
        .distinct,
        .do,
        .drop,
        .each,
        .else,
        .end,
        .escape,
        .except,
        .exclude,
        .exclusive,
        .exists,
        .explain,
        .fail,
        .filter,
        .first,
        .following,
        .for,
        .foreign,
        .from,
        .full,
        .generated,
        .glob,
        .group,
        .groups,
        .having,
        .if,
        .ignore,
        .immediate,
        .in,
        .index,
        .indexed,
        .initially,
        .inner,
        .insert,
        .instead,
        .intersect,
        .into,
        .is,
        .isnull,
        .join,
        .key,
        .last,
        .left,
        .like,
        .limit,
        .match,
        .materialized,
        .natural,
        .no,
        .not,
        .nothing,
        .notnull,
        .null,
        .nulls,
        .of,
        .offset,
        .on,
        .or,
        .order,
        .others,
        .outer,
        .over,
        .partition,
        .plan,
        .pragma,
        .preceding,
        .primary,
        .query,
        .raise,
        .range,
        .recursive,
        .references,
        .regexp,
        .reindex,
        .release,
        .rename,
        .replace,
        .restrict,
        .returning,
        .right,
        .rollback,
        .row,
        .rowid,
        .rows,
        .savepoint,
        .select,
        .set,
        .stored,
        .strict,
        .table,
        .temp,
        .temporary,
        .then,
        .ties,
        .to,
        .transaction,
        .trigger,
        .unbounded,
        .union,
        .unique,
        .update,
        .using,
        .vacuum,
        .values,
        .view,
        .virtual,
        .when,
        .where,
        .window,
        .with,
        .without,
    ].reduce(into: [:]) { $0[$1.description] = $1 }
    
    enum Kind: Hashable {
        case symbol(Substring)
        case string(Substring)
        case numeric(Numeric)
        
//        case double(Numeric)
//        case int(Int)
//        case hex(Int)
        
        case abort
        case action
        case add
        case after
        case all
        case alter
        case always
        case analyze
        case and
        case `as`
        case asc
        case attach
        case autoincrement
        case before
        case begin
        case between
        case by
        case cascade
        case `case`
        case cast
        case check
        case collate
        case column
        case commit
        case conflict
        case constraint
        case create
        case cross
        case current
        case currentDate
        case currentTime
        case currentTimestamp
        case database
        case `default`
        case deferrable
        case deferred
        case delete
        case desc
        case detach
        case distinct
        case `do`
        case drop
        case each
        case `else`
        case end
        case escape
        case except
        case exclude
        case exclusive
        case exists
        case explain
        case fail
        case filter
        case first
        case following
        case `for`
        case foreign
        case from
        case full
        case generated
        case glob
        case group
        case groups
        case having
        case `if`
        case ignore
        case immediate
        case `in`
        case index
        case indexed
        case initially
        case inner
        case insert
        case instead
        case intersect
        case into
        case `is`
        case isnull
        case join
        case key
        case last
        case left
        case like
        case limit
        case match
        case materialized
        case natural
        case no
        case not
        case nothing
        case notnull
        case null
        case nulls
        case of
        case offset
        case on
        case or
        case order
        case others
        case outer
        case over
        case partition
        case plan
        case pragma
        case preceding
        case primary
        case query
        case raise
        case range
        case recursive
        case references
        case regexp
        case reindex
        case release
        case rename
        case replace
        case restrict
        case returning
        case right
        case rollback
        case row
        case rowid
        case rows
        case savepoint
        case select
        case set
        case strict
        case stored
        case table
        case temp
        case temporary
        case then
        case ties
        case to
        case transaction
        case trigger
        case unbounded
        case union
        case unique
        case update
        case using
        case vacuum
        case values
        case view
        case virtual
        case when
        case `where`
        case window
        case with
        case without
        
        // Operators
        case star
        case dot
        case comma
        case semiColon
        case colon
        case dollarSign
        case questionMark
        case openParen
        case closeParen
        case plus
        case minus
        case divide
        case multiply
        case modulo
        case shiftLeft
        case shiftRight
        case ampersand
        case pipe
        case carrot
        case concat
        case tilde
        case doubleEqual
        case notEqual
        case arrow
        case doubleArrow
        
        // Comparisons
        case lt
        case lte
        case gt
        case gte
        
        // Comments
        case dashDash
        case forwardSlashStar
        case starForwardSlash
        
        case eof

        init(word: Substring) {
            // TODO: There has to be a more performant way of doing this.
            if let keyword = Token.keywords[word.uppercased()] {
                self = keyword
            } else {
                self = .symbol(word)
            }
        }
        
        var description: String {
            switch self {
            case .symbol(let value): String(value)
            case .string(let value): String(value)
            case .numeric(let value): value.description
            case .abort: "ABORT"
            case .action: "ACTION"
            case .add: "ADD"
            case .after: "AFTER"
            case .all: "ALL"
            case .alter: "ALTER"
            case .always: "ALWAYS"
            case .analyze: "ANALYZE"
            case .and: "AND"
            case .as: "AS"
            case .asc: "ASC"
            case .attach: "ATTACH"
            case .autoincrement: "AUTOINCREMENT"
            case .before: "BEFORE"
            case .begin: "BEGIN"
            case .between: "BETWEEN"
            case .by: "BY"
            case .cascade: "CASCADE"
            case .case: "CASE"
            case .cast: "CAST"
            case .check: "CHECK"
            case .collate: "COLLATE"
            case .column: "COLUMN"
            case .commit: "COMMIT"
            case .conflict: "CONFLICT"
            case .constraint: "CONSTRAINT"
            case .create: "CREATE"
            case .cross: "CROSS"
            case .current: "CURRENT"
            case .currentDate: "CURRENT_DATE"
            case .currentTime: "CURRENT_TIME"
            case .currentTimestamp: "CURRENT_TIMESTAMP"
            case .database: "DATABASE"
            case .default: "DEFAULT"
            case .deferrable: "DEFERRABLE"
            case .deferred: "DEFERRED"
            case .delete: "DELETE"
            case .desc: "DESC"
            case .detach: "DETACH"
            case .distinct: "DISTINCT"
            case .do: "DO"
            case .drop: "DROP"
            case .each: "EACH"
            case .else: "ELSE"
            case .end: "END"
            case .escape: "ESCAPE"
            case .except: "EXCEPT"
            case .exclude: "EXCLUDE"
            case .exclusive: "EXCLUSIVE"
            case .exists: "EXISTS"
            case .explain: "EXPLAIN"
            case .fail: "FAIL"
            case .filter: "FILTER"
            case .first: "FIRST"
            case .following: "FOLLOWING"
            case .for: "FOR"
            case .foreign: "FOREIGN"
            case .from: "FROM"
            case .full: "FULL"
            case .generated: "GENERATED"
            case .glob: "GLOB"
            case .group: "GROUP"
            case .groups: "GROUPS"
            case .having: "HAVING"
            case .if: "IF"
            case .ignore: "IGNORE"
            case .immediate: "IMMEDIATE"
            case .in: "IN"
            case .index: "INDEX"
            case .indexed: "INDEXED"
            case .initially: "INITIALLY"
            case .inner: "INNER"
            case .insert: "INSERT"
            case .instead: "INSTEAD"
            case .intersect: "INTERSECT"
            case .into: "INTO"
            case .is: "IS"
            case .isnull: "ISNULL"
            case .join: "JOIN"
            case .key: "KEY"
            case .last: "LAST"
            case .left: "LEFT"
            case .like: "LIKE"
            case .limit: "LIMIT"
            case .match: "MATCH"
            case .materialized: "MATERIALIZED"
            case .natural: "NATURAL"
            case .no: "NO"
            case .not: "NOT"
            case .nothing: "NOTHING"
            case .notnull: "NOTNULL"
            case .null: "NULL"
            case .nulls: "NULLS"
            case .of: "OF"
            case .offset: "OFFSET"
            case .on: "ON"
            case .or: "OR"
            case .order: "ORDER"
            case .others: "OTHERS"
            case .outer: "OUTER"
            case .over: "OVER"
            case .partition: "PARTITION"
            case .plan: "PLAN"
            case .pragma: "PRAGMA"
            case .preceding: "PRECEDING"
            case .primary: "PRIMARY"
            case .query: "QUERY"
            case .raise: "RAISE"
            case .range: "RANGE"
            case .recursive: "RECURSIVE"
            case .references: "REFERENCES"
            case .regexp: "REGEXP"
            case .reindex: "REINDEX"
            case .release: "RELEASE"
            case .rename: "RENAME"
            case .replace: "REPLACE"
            case .restrict: "RESTRICT"
            case .returning: "RETURNING"
            case .right: "RIGHT"
            case .rollback: "ROLLBACK"
            case .row: "ROW"
            case .rowid: "ROWID"
            case .rows: "ROWS"
            case .savepoint: "SAVEPOINT"
            case .select: "SELECT"
            case .set: "SET"
            case .strict: "STRICT"
            case .stored: "STORED"
            case .table: "TABLE"
            case .temp: "TEMP"
            case .temporary: "TEMPORARY"
            case .then: "THEN"
            case .ties: "TIES"
            case .to: "TO"
            case .transaction: "TRANSACTION"
            case .trigger: "TRIGGER"
            case .unbounded: "UNBOUNDED"
            case .union: "UNION"
            case .unique: "UNIQUE"
            case .update: "UPDATE"
            case .using: "USING"
            case .vacuum: "VACUUM"
            case .values: "VALUES"
            case .view: "VIEW"
            case .virtual: "VIRTUAL"
            case .when: "WHEN"
            case .where: "WHERE"
            case .window: "WINDOW"
            case .with: "WITH"
            case .without: "WITHOUT"
            case .star: "*"
            case .dot: "."
            case .comma: ","
            case .semiColon: ";"
            case .colon: ":"
            case .dollarSign: "$"
            case .questionMark: "?"
            case .openParen: "("
            case .closeParen: ")"
            case .plus: "+"
            case .minus: "-"
            case .divide: "/"
            case .multiply: "*"
            case .modulo: "%"
            case .shiftLeft: "<<"
            case .shiftRight: ">>"
            case .ampersand: "&"
            case .pipe: "|"
            case .carrot: "^"
            case .concat: "||"
            case .tilde: "~"
            case .doubleEqual: "=="
            case .notEqual: "!="
            case .arrow: "->"
            case .doubleArrow: "->>"
            case .lt: "<"
            case .lte: "<="
            case .gt: ">"
            case .gte: ">="
            case .dashDash: "--"
            case .forwardSlashStar: "/*"
            case .starForwardSlash: "*/"
            case .eof: "EOF"
            }
        }
    }
}

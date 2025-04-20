package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:unicode/utf8"
import u "core:unicode"

TokenType :: enum {
    ascii,
    eof = 256,
    error,
    ident,         // is [_a-zA-Z][_a-zA-Z0-9]*
    lit_int,       // is [0-9]+  |  0x[0-9a-fA-F]+  |  0o[0-7]+  |  0b[0-1]+
    lit_float,     // is [0-9]*(.[0-9]*([eE][-+]?[0-9]+)?)
    lit_dq_string, // is "string"
    lit_sq_string, // is 'string'
    lit_bq_string, // is `string`
}

Token :: struct {
    type: TokenType,
    data: string,
}

Lexer :: struct {
    // lexer variables
    input: []rune,
    storage: [dynamic]Token,
    parse_point: int,

    // lexer parse location for error messages
    where_firstchar,
    where_lastchar: int,

    // lexer token variables
    token: Token,
}

main :: proc() {
    // {{{ Tracking + Temp. Allocator
    // taken from youtube.com/watch?v=dg6qogN8kIE
    tracking_allocator : mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)
    defer {
        for key, value in tracking_allocator.allocation_map {
            fmt.printf("[%v] %v leaked %v bytes\n", key, value.location, value.size)
        }
        for value in tracking_allocator.bad_free_array {
            fmt.printf("[%v] %v double free detected\n", value.memory, value.location)
        }
        mem.tracking_allocator_clear(&tracking_allocator)
    }
    defer free_all(context.temp_allocator)
    // }}}

    input_file, ok := os.read_entire_file_from_filename("test.c")
    assert(ok, "Could not open input file")
    defer delete(input_file)

    input := utf8.string_to_runes(string(input_file))
    defer delete(input)

    // fmt.println(string(input_file))

    storage : [dynamic]Token
    defer delete(storage)

    lexer : Lexer
    lex_init(&lexer, &input, &storage)
    fmt.println(lex_once(&lexer))
}

lex_init :: proc(lexer: ^Lexer, input: ^[]rune, storage: ^[dynamic]Token) {
    lexer.input = input^
    lexer.storage = storage^
}

lex_once :: proc(lexer: ^Lexer) -> Token {
    return Token{}
}

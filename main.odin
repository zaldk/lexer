package main

import "core:fmt"
import "core:os"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import u "core:unicode"

TokenType :: enum {
    ascii,
    error = 256,
    eof,
    ident, // is [_a-zA-Z][_a-zA-Z0-9]*
    number,
    string,
    // lit_int,       // is [0-9]+  |  0x[0-9a-fA-F]+  |  0o[0-7]+  |  0b[0-1]+
    // lit_float,     // is [0-9]*(.[0-9]*([eE][-+]?[0-9]+)?)
    // lit_dq_string, // is "string"
    // lit_sq_string, // is 'string'
    // lit_bq_string, // is `string`
}

Token :: struct {
    type: TokenType,
    data: [dynamic]rune,
}

Lexer :: struct {
    // lexer variables
    input: []rune,
    storage: [dynamic]rune,

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



    lexer : Lexer
    defer delete(lexer.storage)
    lex_init(&lexer, &input)
    for i in 0..<10 {
        lex_once(&lexer)
        fmt.printfln("type: %v | data: %v", lexer.token.type, lexer.token.data[1:])
    }
}

lex_init :: proc(lexer: ^Lexer, input: ^[]rune) {
    lexer.input = input^
}

lex_once :: proc(lexer: ^Lexer) {
    token := &lexer.storage[len(lexer.storage)-1]
    p := lexer.input

    for {
        if len(p) == 0 { return } // there was no valid text until EOF
        if !u.is_space(p[0]) {
            if len(p) >= 2 {
                if p[0] == '/' && p[1] == '/' {
                    panic("TODO: implement single-line comment skip")
                } else if p[0] == '/' && p[1] == '*' {
                    panic("TODO: implement multi-line comment skip")
                } else { break }
            }
            break
        }
        p = p[1:]
    }

    if len(p) == 0 { return } // there was no valid text until EOF

    switch {
    case u.is_letter(p[0]) || p[0] != '_': { // identifier ::= [_a-zA-Z][_a-zA-Z0-9]*
        sb := ""
        defer strings.builder_destroy(&sb)
        for {
            if len(p) == 0 || !u.is_letter(p[0]) && !u.is_digit(p[0]) && p[0] != '_' { break }
            strings.write_rune(&sb, p[0])
            p = p[1:]
        }
        token.type = .ident
        data_str := strings.to_string(sb)
        for r in data_str {
            append(&token.data, r)
        }
    }
    case u.is_digit(p[0]): { }  // number literal
    case: {
        token.type = .ascii
        append(&token.data, p[0])
    }
    }

    lexer.input = p[1:]

    return
}

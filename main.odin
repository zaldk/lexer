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
    data: string,
}

Tokenizer :: struct {
    src: string,
    offset: int,
    read_offset: int,
    token: Token,
    ch: rune,
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

    t : Tokenizer
    lex_init(&t, string(input_file))
    for i in 0..<10 {
        lex_once(&t)
        fmt.printfln("type: %v | offset: %c | read_offset: %c | ch: %c | data: %v",
            t.token.type, t.src[t.offset], t.src[t.read_offset], t.ch, t.token.data)
    }
}

lex_init :: proc(tok: ^Tokenizer, input: string) {
    tok.src = input
}

lex_once :: proc(t: ^Tokenizer) {
    for {
        if !u.is_space(t.ch) {
            if t.offset < len(t.src)-2 {
                if peek_byte(t,0) == '/' && peek_byte(t,1) == '/' {
                    panic("TODO: implement single-line comment skip")
                } else if peek_byte(t,0) == '/' && peek_byte(t,1) == '*' {
                    panic("TODO: implement multi-line comment skip")
                } else { break }
            }
            break
        }
        advance_rune(t)
        if t.ch == -1 { return } // there was no valid text until EOF
    }

    offset := t.offset
    switch {
    case u.is_letter(t.ch) || t.ch == '_': { // identifier ::= [_a-zA-Z][_a-zA-Z0-9]*
        for {
            if t.ch == -1 || t.read_offset > len(t.src) || !u.is_letter(t.ch) && !u.is_digit(t.ch) && t.ch != '_' { break }
            advance_rune(t)
        }
        t.token.type = .ident
        t.token.data = t.src[offset : t.read_offset]
        // fmt.println("\nTOKEN:", t.token, "\n")
    }
    case u.is_digit(t.ch): {
        advance_rune(t)
    } // number literal
    case: {
        advance_rune(t)
        t.token.type = .ascii
        t.token.data = t.src[offset:][:1]
    }
    }

    return
}

advance_rune :: proc(t: ^Tokenizer) {
    if t.read_offset < len(t.src) {
        t.offset = t.read_offset
        r, w := rune(t.src[t.read_offset]), 1
        switch {
        case r == 0:
            panic("Illegal character NUL")
        case r >= utf8.RUNE_SELF:
            r, w = utf8.decode_rune_in_string(t.src[t.read_offset:])
            if r == utf8.RUNE_ERROR && w == 1 {
                panic("Illegal UTF-8 encoding")
            } else if r == utf8.RUNE_BOM && t.offset > 0 {
                panic("Illegal byte order mark")
            }
        }
        t.read_offset += w
        t.ch = r
    } else {
        t.offset = len(t.src)
        t.ch = -1
    }
}

peek_byte :: proc(t: ^Tokenizer, offset := 0) -> byte {
    if t.read_offset+offset < len(t.src) {
        return t.src[t.read_offset+offset]
    }
    return 0
}

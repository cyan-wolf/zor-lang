const Compiler = @import("compiler.zig").Compiler;

pub const Precendence = enum {
    none,
    assignment, // =
    p_or, // or
    p_and, // and
    equality, // == !=
    comparison, // < > <= >=
    term, // + -
    factor, // * /
    unary, // ! -
    call, // . ()
    primary,
};

const ParseFnError = error{
    OutOfMemory,
    InvalidCharacter,
};

pub const ParseFn = *const fn (*Compiler) ParseFnError!void;

pub const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precendence,
};

const Compiler = @import("compiler.zig").Compiler;

pub const Precedence = enum {
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

    pub fn withOneMoreBindingPower(self: Precedence) Precedence {
        return @enumFromInt(@intFromEnum(self) + 1);
    }

    pub fn hasLessOrEqBindingPowerThan(self: Precedence, other: Precedence) bool {
        return @intFromEnum(self) <= @intFromEnum(other);
    }
};

const ParseFnError = error{
    OutOfMemory,
    InvalidCharacter,
};

pub const ParseContext = struct {
    can_assign: bool = false,
};

pub const ParseFn = *const fn (*Compiler, ParseContext) ParseFnError!void;

pub const ParseRule = struct {
    prefix: ?ParseFn,
    infix: ?ParseFn,
    precedence: Precedence,
};

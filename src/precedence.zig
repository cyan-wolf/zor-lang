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

    pub fn withOneMoreBindingPower(self: Precendence) Precendence {
        return @enumFromInt(@intFromEnum(self) + 1);
    }

    pub fn hasLessOrEqBindingPowerThan(self: Precendence, other: Precendence) bool {
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
    precedence: Precendence,
};

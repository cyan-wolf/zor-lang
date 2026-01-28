
pub const TokenKind = enum {
    // Parentheses.
    left_paren,
    right_paren,
    left_brace,
    right_brace,

    // Single character operators.
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // Equality.
    bang,
    bang_equal,
    equal,
    double_equal,

    // Comparison operators.
    greater,
    greater_equal,
    less,
    less_equal,

    // Literals.
    identifier,
    string,
    number,

    // Keywords (prefixed by k_* to avoid conflicts with Zig's keywords)
    k_and,
    k_class,
    k_else,
    k_false,
    k_for,
    k_fun,
    k_if,
    k_nil,
    k_or,
    k_print,
    k_return,
    k_super,
    k_this,
    k_true,
    k_var,
    k_while,

    // Misc.
    none,
    error_token,
    eof,
};

pub const Token = struct {
    kind: TokenKind,
    text_ref: []const u8,
    line: usize,

    pub fn createDummyInitialToken() Token {
        return .{
            .kind = .none,
            .text_ref = "",
            .line = 0,
        };
    }
};


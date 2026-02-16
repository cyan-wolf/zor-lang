const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const CodeContent = chunk_mod.CodeContent;
const Value = chunk_mod.Value;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;
const precedence_mod = @import("precedence.zig");
const Precendence = precedence_mod.Precendence;
const ParseRule = precedence_mod.ParseRule;

const DEBUG_PRINT_CODE = true;

pub const Parser = struct {
    current: Token,
    previous: Token,
    had_error: bool,
    in_panic_mode: bool,

    pub fn init() Parser {
        return .{
            .current = Token.createDummyInitialToken(),
            .previous = Token.createDummyInitialToken(),
            .had_error = false,
            .in_panic_mode = false,
        };
    }
};

pub const Compiler = struct {
    source: []const u8,
    scanner: Scanner,
    parser: Parser,
    complingChunk: *Chunk,

    allocator: std.mem.Allocator,

    rules: std.enums.EnumArray(TokenKind, ParseRule),

    pub fn init(source: []const u8, alloctor: std.mem.Allocator) Compiler {
        return .{
            .source = source,
            .scanner = Scanner.init(source),
            .parser = Parser.init(),
            .complingChunk = undefined,

            .allocator = alloctor,

            .rules = std.enums.EnumArray(TokenKind, ParseRule).init(.{
                .left_paren = .{ .prefix = Compiler.grouping, .infix = null, .precedence = .none },
                .right_paren = .{ .prefix = null, .infix = null, .precedence = .none },
                .left_brace = .{ .prefix = null, .infix = null, .precedence = .none },
                .right_brace = .{ .prefix = null, .infix = null, .precedence = .none },
                .comma = .{ .prefix = null, .infix = null, .precedence = .none },
                .dot = .{ .prefix = null, .infix = null, .precedence = .none },
                .minus = .{ .prefix = Compiler.unary, .infix = Compiler.binary, .precedence = .term },
                .plus = .{ .prefix = null, .infix = Compiler.binary, .precedence = .term },
                .semicolon = .{ .prefix = null, .infix = null, .precedence = .none },
                .slash = .{ .prefix = null, .infix = Compiler.binary, .precedence = .factor },
                .star = .{ .prefix = null, .infix = Compiler.binary, .precedence = .factor },
                .bang = .{ .prefix = null, .infix = null, .precedence = .none },
                .bang_equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .double_equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .greater = .{ .prefix = null, .infix = null, .precedence = .none },
                .greater_equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .less = .{ .prefix = null, .infix = null, .precedence = .none },
                .less_equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .identifier = .{ .prefix = null, .infix = null, .precedence = .none },
                .string = .{ .prefix = null, .infix = null, .precedence = .none },
                .number = .{ .prefix = Compiler.number, .infix = null, .precedence = .none },
                .k_and = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_or = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_class = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_else = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_false = .{ .prefix = Compiler.literal, .infix = null, .precedence = .none },
                .k_for = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_fun = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_if = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_nil = .{ .prefix = Compiler.literal, .infix = null, .precedence = .none },
                .k_print = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_return = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_super = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_this = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_true = .{ .prefix = Compiler.literal, .infix = null, .precedence = .none },
                .k_var = .{ .prefix = null, .infix = null, .precedence = .none },
                .k_while = .{ .prefix = null, .infix = null, .precedence = .none },
                .error_token = .{ .prefix = null, .infix = null, .precedence = .none },
                .eof = .{ .prefix = null, .infix = null, .precedence = .none },
                .none = .{ .prefix = null, .infix = null, .precedence = .none },
            }),
        };
    }

    pub fn compile(self: *Compiler, chunk: *Chunk) !bool {
        self.complingChunk = chunk;

        self.advance();
        try self.expression();
        self.consume(.eof, "End of expression.");

        try self.end();
        return !self.parser.had_error;
    }

    fn advance(self: *Compiler) void {
        std.debug.print("Moving from {s} to {s}\n", .{ @tagName(self.parser.previous.kind), @tagName(self.parser.current.kind) });

        self.parser.previous = self.parser.current;

        while (true) {
            self.parser.current = self.scanner.scanToken();
            if (self.parser.current.kind != .error_token) {
                break;
            }
            self.markErrorAtCurrent(self.parser.current.text_ref);
        }
    }

    fn getRule(self: *const Compiler, kind: TokenKind) ParseRule {
        return self.rules.get(kind);
    }

    fn markErrorAtCurrent(self: *Compiler, message: []const u8) void {
        self.markErrorAt(self.parser.current, message);
    }

    fn markError(self: *Compiler, message: []const u8) void {
        self.markErrorAt(self.parser.previous, message);
    }

    fn markErrorAt(self: *Compiler, token: Token, message: []const u8) void {
        if (self.parser.in_panic_mode) {
            return;
        }
        self.parser.in_panic_mode = true;

        std.debug.print("[line {d}] Error", .{token.line});

        if (token.kind == .eof) {
            std.debug.print(" at end", .{});
        } else if (token.kind == .error_token) {
            // No print.
        } else {
            std.debug.print(" at '{s}'", .{token.text_ref});
        }
        std.debug.print(": {s} \n", .{message});
        self.parser.had_error = true;
    }

    fn currentChunk(self: *Compiler) *Chunk {
        return self.complingChunk;
    }

    fn consume(self: *Compiler, kind: TokenKind, message: []const u8) void {
        if (self.parser.current.kind == kind) {
            self.advance();
            return;
        }
        std.debug.print("WRONG --> {s} hmmm {d}\n", .{ @tagName(self.parser.current.kind), self.scanner.current });
        self.markErrorAtCurrent(message);
    }

    fn expression(self: *Compiler) !void {
        try self.parseWithPrecendece(.assignment);
    }

    fn emitByte(self: *Compiler, byte: CodeContent) !void {
        try self.currentChunk().write(self.allocator, byte, self.parser.previous.line);
    }

    fn emitCode(self: *Compiler, code: OpCode) !void {
        try self.emitByte(@intFromEnum(code));
    }

    fn emitCodeAndOperand(self: *Compiler, code: OpCode, operand: CodeContent) !void {
        try self.emitCode(code);
        try self.emitByte(operand);
    }

    fn end(self: *Compiler) !void {
        try self.emitReturn();

        if (DEBUG_PRINT_CODE) {
            if (!self.parser.had_error) {
                self.currentChunk().disassemble("code");
            }
        }
    }

    fn number(self: *Compiler) !void {
        const value = Value.fromNumber(try std.fmt.parseFloat(f64, self.parser.previous.text_ref));
        try self.emitConstant(value);
    }

    fn unary(self: *Compiler) !void {
        const prev_kind = self.parser.previous.kind;

        // Compile the operand of the unary expression.
        try self.parseWithPrecendece(.unary);

        switch (prev_kind) {
            .minus => try self.emitCode(.negate),
            else => unreachable,
        }
    }

    fn binary(self: *Compiler) !void {
        const op_kind = self.parser.previous.kind;
        const rule = self.getRule(op_kind);

        try self.parseWithPrecendece(rule.precedence.withOneMoreBindingPower());

        switch (op_kind) {
            .plus => try self.emitCode(.add),
            .minus => try self.emitCode(.subtract),
            .star => try self.emitCode(.multiply),
            .slash => try self.emitCode(.divide),
            else => unreachable,
        }
    }

    fn literal(self: *Compiler) !void {
        const op_kind = self.parser.previous.kind;

        switch(op_kind) {
            .k_false => try self.emitCode(.code_false),
            .k_nil => try self.emitCode(.nil),
            .k_true => try self.emitCode(.code_true),
            else => unreachable,
        }
    }

    fn parseWithPrecendece(self: *Compiler, precendence: Precendence) !void {
        self.advance();

        const prefix_rule = self.getRule(self.parser.previous.kind).prefix;

        if (prefix_rule == null) {
            self.markError("Expect expression");
            return;
        }
        try prefix_rule.?(self);

        while (precendence.hasLessOrEqBindingPowerThan(self.getRule(self.parser.current.kind).precedence)) {
            self.advance();

            const infix_rule = self.getRule(self.parser.previous.kind).infix;

            try infix_rule.?(self);
        }
    }

    fn grouping(self: *Compiler) !void {
        try self.expression();
        self.consume(.right_paren, "Expect ')' after expression.");
    }

    fn emitReturn(self: *Compiler) !void {
        try self.emitCode(.opreturn);
    }

    fn emitConstant(self: *Compiler, value: Value) !void {
        try self.emitCodeAndOperand(.constant, try self.makeConstant(value));
    }

    fn makeConstant(self: *Compiler, value: Value) !CodeContent {
        const constIdx = try self.currentChunk().addConstant(self.allocator, value);

        if (constIdx > std.math.maxInt(CodeContent)) {
            self.markError("Too many constants in one chunk.");
            return 0;
        }
        return @intCast(constIdx);
    }
};

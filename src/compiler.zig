const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const CodeContent = chunk_mod.CodeContent;
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const Obj = value_mod.Obj;
const ObjString = value_mod.ObjString;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;
const precedence_mod = @import("precedence.zig");
const Precendence = precedence_mod.Precendence;
const Parsecontext = precedence_mod.ParseContext;
const ParseRule = precedence_mod.ParseRule;
const AllocMonitor = @import("vm.zig").AllocMonitor;
const LocalsInfo = @import("locals.zig").LocalsInfo;

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

    rules: std.enums.EnumArray(TokenKind, ParseRule),

    locals_info: LocalsInfo,

    allocator: std.mem.Allocator,
    alloc_monitor: *AllocMonitor,

    pub fn init(source: []const u8, alloctor: std.mem.Allocator, alloc_monitor: *AllocMonitor) Compiler {
        return .{
            .source = source,
            .scanner = Scanner.init(source),
            .parser = Parser.init(),
            .complingChunk = undefined,

            .locals_info = .{},

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
                .bang = .{ .prefix = Compiler.unary, .infix = null, .precedence = .none },
                .bang_equal = .{ .prefix = null, .infix = Compiler.binary, .precedence = .equality },
                .equal = .{ .prefix = null, .infix = null, .precedence = .none },
                .double_equal = .{ .prefix = null, .infix = Compiler.binary, .precedence = .equality },
                .greater = .{ .prefix = null, .infix = Compiler.binary, .precedence = .comparison },
                .greater_equal = .{ .prefix = null, .infix = Compiler.binary, .precedence = .comparison },
                .less = .{ .prefix = null, .infix = Compiler.binary, .precedence = .comparison },
                .less_equal = .{ .prefix = null, .infix = Compiler.binary, .precedence = .comparison },
                .identifier = .{ .prefix = Compiler.variable, .infix = null, .precedence = .none },
                .string = .{ .prefix = Compiler.string, .infix = null, .precedence = .none },
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

            .allocator = alloctor,
            .alloc_monitor = alloc_monitor,
        };
    }

    pub fn compile(self: *Compiler, chunk: *Chunk) !bool {
        self.complingChunk = chunk;

        self.advance();

        while (!self.match(.eof)) {
            try self.statement();
        }

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

    fn match(self: *Compiler, kind: TokenKind) bool {
        if (!self.check(kind)) {
            return false;
        }
        self.advance();
        return true;
    }

    fn check(self: *Compiler, kind: TokenKind) bool {
        return self.parser.current.kind == kind;
    }

    fn expression(self: *Compiler) !void {
        try self.parseWithPrecendece(.assignment);
    }

    // This has an explicit error set in the function definition
    // because block(...) <-> statement(...) have a recursive relationship,
    // which breaks Zig's error set inference.
    fn block(self: *Compiler) error{ OutOfMemory, InvalidCharacter }!void {
        while (!self.check(.right_brace) and !self.check(.eof)) {
            try self.statement();
        }

        self.consume(.right_brace, "Expected '}' after block.");
    }

    fn statement_print(self: *Compiler) !void {
        try self.expression();
        self.consume(.semicolon, "Expected ';' after expression.");
        try self.emitCode(.print);
    }

    fn statement_expression(self: *Compiler) !void {
        try self.expression();
        self.consume(.semicolon, "Expected ';' after expression.");
        try self.emitCode(.pop);
    }

    fn synchronize(self: *Compiler) void {
        self.parser.in_panic_mode = false;

        while (self.parser.current.kind != .eof) {
            if (self.parser.previous.kind == .semicolon) {
                return;
            }

            switch (self.parser.current.kind) {
                .k_class, .k_fun, .k_var, .k_for, .k_if, .k_while, .k_print, .k_return => {
                    return;
                },
                else => {},
            }
        }
        self.advance();
    }

    fn statement(self: *Compiler) !void {
        if (self.match(.k_var)) {
            try self.variable_declaration();
            return;
        }

        if (self.match(.k_print)) {
            try self.statement_print();
        } else if (self.match(.left_brace)) {
            try self.beginScope();
            try self.block();
            try self.endScope();
        }

        if (self.parser.in_panic_mode) {
            self.synchronize();
        }
    }

    fn variable_declaration(self: *Compiler) !void {
        const global_var_idx = try self.parseVariable("Expected variable name.");

        if (self.match(.equal)) {
            try self.expression();
        } else {
            try self.emitCode(.nil);
        }
        self.consume(.semicolon, "Expected ';' after variable declaration.");

        try self.defineVariable(global_var_idx);
    }

    fn parseVariable(self: *Compiler, error_message: []const u8) !usize {
        self.consume(.identifier, error_message);
        return try self.identifierConstant(self.parser.previous);
    }

    fn declareVariable(self: *Compiler) !void {
        // If the scope depth is zero, then this is a global variable.
        // Global variables are late bound and hence have different logic
        // for declaring them/
        if (self.locals_info.scope_depth == 0) {
            return;
        }
        const name = self.parser.previous;
        self.addLocal(name);
    }

    fn addLocal(self: *Compiler, name: Token) !void {
        self.locals_info.locals.append(self.allocator, .{
            .name = name,
            .depth = self.locals_info.scope_depth,
        });
    }

    fn defineVariable(self: *Compiler, global_var_idx: usize) !void {
        // If the scope depth is greater than zero, then we are defining a
        // local variable. In that case we exit the function the function early
        // before we emit the code used for definining a global variable.
        if (self.locals_info.scope_depth > 0) {
            return;
        }

        try self.emitCodeAndOperand(.define_global, @intCast(global_var_idx));
    }

    fn identifierConstant(self: *Compiler, name_source: Token) !usize {
        const name = try self.alloc_monitor.createOrGetInternedObjString(name_source.text_ref);
        return try self.makeConstant(Value.fromObj(name.as_obj()));
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

    fn beginScope(self: *Compiler) !void {
        self.locals_info.scope_depth += 1;
    }

    fn endScope(self: *Compiler) !void {
        self.locals_info.scope_depth -= 1;
    }

    fn end(self: *Compiler) !void {
        try self.emitReturn();

        if (DEBUG_PRINT_CODE) {
            if (!self.parser.had_error) {
                self.currentChunk().disassemble("code");
            }
        }
    }

    fn number(self: *Compiler, _: Parsecontext) !void {
        const value = Value.fromNumber(try std.fmt.parseFloat(f64, self.parser.previous.text_ref));
        try self.emitConstant(value);
    }

    fn string(self: *Compiler, _: Parsecontext) !void {
        const string_data = self.parser.previous.text_ref[1 .. self.parser.previous.text_ref.len - 1];
        const obj_string = try self.alloc_monitor.createOrGetInternedObjString(string_data);

        try self.emitConstant(Value.fromObj(@ptrCast(obj_string)));
    }

    fn variable(self: *Compiler, ctx: Parsecontext) !void {
        try self.namedVariable(self.parser.previous, ctx);
    }

    fn namedVariable(self: *Compiler, name: Token, ctx: Parsecontext) !void {
        const arg_idx = try self.identifierConstant(name);

        if (ctx.can_assign and self.match(.equal)) {
            try self.expression();
            try self.emitCodeAndOperand(.set_global, @intCast(arg_idx));
        } else {
            try self.emitCodeAndOperand(.get_global, @intCast(arg_idx));
        }
    }

    fn unary(self: *Compiler, _: Parsecontext) !void {
        const prev_kind = self.parser.previous.kind;

        // Compile the operand of the unary expression.
        try self.parseWithPrecendece(.unary);

        switch (prev_kind) {
            .minus => try self.emitCode(.negate),
            .bang => try self.emitCode(.not),
            else => unreachable,
        }
    }

    fn binary(self: *Compiler, _: Parsecontext) !void {
        const op_kind = self.parser.previous.kind;
        const rule = self.getRule(op_kind);

        try self.parseWithPrecendece(rule.precedence.withOneMoreBindingPower());

        switch (op_kind) {
            .bang_equal => try self.emitCodeAndOperand(.equal, @intFromEnum(OpCode.not)),
            .double_equal => try self.emitCode(.equal),
            .greater => try self.emitCode(.greater),
            .greater_equal => try self.emitCodeAndOperand(.less, @intFromEnum(OpCode.not)),
            .less => try self.emitCode(.less),
            .less_equal => try self.emitCodeAndOperand(.greater, @intFromEnum(OpCode.not)),
            .plus => try self.emitCode(.add),
            .minus => try self.emitCode(.subtract),
            .star => try self.emitCode(.multiply),
            .slash => try self.emitCode(.divide),
            else => unreachable,
        }
    }

    fn literal(self: *Compiler, _: Parsecontext) !void {
        const op_kind = self.parser.previous.kind;

        switch (op_kind) {
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
        const can_assign = precendence.hasLessOrEqBindingPowerThan(.assignment);
        try prefix_rule.?(self, .{ .can_assign = can_assign });

        while (precendence.hasLessOrEqBindingPowerThan(self.getRule(self.parser.current.kind).precedence)) {
            self.advance();

            const infix_rule = self.getRule(self.parser.previous.kind).infix;

            try infix_rule.?(self, .{ .can_assign = can_assign });
        }

        if (can_assign and self.match(.equal)) {
            self.markError("Invalid assignment target.");
        }
    }

    fn grouping(self: *Compiler, _: Parsecontext) !void {
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

    pub fn deinit(self: *Compiler) void {
        self.locals_info.deinit(self.allocator);
    }
};

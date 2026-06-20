const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const CodeContent = chunk_mod.CodeContent;
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const Obj = value_mod.Obj;
const ObjFunction = value_mod.ObjFunction;
const ObjString = value_mod.ObjString;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;
const precedence_mod = @import("precedence.zig");
const Precendence = precedence_mod.Precedence;
const ParseContext = precedence_mod.ParseContext;
const ParseRule = precedence_mod.ParseRule;
const vm_mod = @import("vm.zig");
const AllocMonitor = vm_mod.AllocMonitor;
const ZorConfig = vm_mod.ZorConfig;
const LocalsInfo = @import("locals.zig").LocalsInfo;

const OpPair = struct {
    get: OpCode,
    set: OpCode,
};

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

const FunctionKind = enum {
    function,
    script,
};

pub const FunctionCompiler = struct {
    locals_info: LocalsInfo,
    curr_function: *ObjFunction,
    curr_function_kind: FunctionKind,

    // NOTE: This pointer has really bad lifecyle semantics, it might be better to allocate all the
    // `FunctionCompiler`s in an arena managed by the `Compiler` and instead `enclosing` refers to function-compilers
    // by index instead of by pointer.
    enclosing: ?*FunctionCompiler,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, func_kind: FunctionKind, enclosing: ?*FunctionCompiler) !FunctionCompiler {
        return .{
            .locals_info = try LocalsInfo.init(allocator),
            .curr_function = try ObjFunction.createNew(allocator),
            .curr_function_kind = func_kind,
            .enclosing = enclosing,

            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FunctionCompiler) void {
        self.locals_info.deinit(self.allocator);
    }
};

pub const Compiler = struct {
    config: ZorConfig,

    source: []const u8,
    scanner: Scanner,
    parser: Parser,

    func_context: *FunctionCompiler,

    rules: std.enums.EnumArray(TokenKind, ParseRule),

    allocator: std.mem.Allocator,
    alloc_monitor: *AllocMonitor,

    pub fn init(source: []const u8, allocator: std.mem.Allocator, alloc_monitor: *AllocMonitor, config: ZorConfig) !Compiler {
        return .{
            .config = config,

            .source = source,
            .scanner = Scanner.init(source),
            .parser = Parser.init(),

            .func_context = undefined,

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
                .k_and = .{ .prefix = null, .infix = Compiler.and_, .precedence = .p_and },
                .k_or = .{ .prefix = null, .infix = Compiler.or_, .precedence = .p_or },
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

            .allocator = allocator,
            .alloc_monitor = alloc_monitor,
        };
    }

    pub fn compile(self: *Compiler) !?*ObjFunction {
        // The top-level of the script is denoted by a special function of kind `script`.
        var root_func_context = try FunctionCompiler.init(self.allocator, .script, null);
        defer root_func_context.deinit();

        self.func_context = &root_func_context;

        self.advance();

        while (!self.match(.eof)) {
            try self.statement();
        }

        const function = try self.finish();
        if (self.parser.had_error) {
            return null;
        } else {
            return function;
        }
    }

    fn advance(self: *Compiler) void {
        if (self.config.trace_parser_advance) {
            std.debug.print("[Parser] {s} -> {s}\n", .{ @tagName(self.parser.previous.kind), @tagName(self.parser.current.kind) });
        }

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
        return &self.func_context.curr_function.chunk;
    }

    fn consume(self: *Compiler, kind: TokenKind, message: []const u8) void {
        if (self.parser.current.kind == kind) {
            self.advance();
            return;
        }
        std.debug.print("[Parser] Error Log: unexpected {s} at {d}\n", .{ @tagName(self.parser.current.kind), self.scanner.current });
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
        try self.parseWithPrecedence(.assignment);
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
            self.advance();
        }
    }

    // NOTE: This parses Rust-style if statements (optional parentheses and a required block)
    // i.e. if <cond> {<stmt1>; <stmt2}; ... ) rather than if (<cond>) <stmt | block>
    fn statementIf(self: *Compiler) !void {
        try self.expression();

        self.consume(.left_brace, "Expected '{' before if body.");

        const thenJump = try self.emitJump(.jump_if_false);
        try self.emitCode(.pop);

        try self.beginScope();
        try self.block();
        try self.endScope();

        const elseJump = try self.emitJump(.jump);
        try self.patchJump(thenJump);
        try self.emitCode(.pop);

        if (self.match(.k_else)) {
            self.consume(.left_brace, "Expected '{' before else body.");

            try self.beginScope();
            try self.block();
            try self.endScope();
        }
        try self.patchJump(elseJump);
    }

    fn statementWhile(self: *Compiler) !void {
        const loopStart = self.currentChunk().code.items.len;
        try self.expression();

        self.consume(.left_brace, "Expected '{' before while body.");

        const exitJump = try self.emitJump(.jump_if_false);
        try self.emitCode(.pop);

        try self.beginScope();
        try self.block();
        try self.endScope();

        try self.emitLoop(loopStart);

        try self.patchJump(exitJump);
        try self.emitCode(.pop);
    }

    fn statementFor(self: *Compiler) !void {
        try self.beginScope(); // for scoping variables in initializer

        if (self.match(.semicolon)) {
            // No initializer.
        } else if (self.match(.k_var)) {
            try self.variableDeclaration();
        } else {
            try self.expressionStatement();
        }

        var loop_start = self.currentChunk().code.items.len;

        var exit_jump: ?usize = null;
        if (!self.match(.semicolon)) {
            try self.expression();
            self.consume(.semicolon, "Expected ';' after loop condition.");

            exit_jump = try self.emitJump(.jump_if_false);
            try self.emitCode(.pop);
        }

        // Increment clause.
        if (!self.check(.left_brace)) {
            const body_jump = try self.emitJump(.jump);
            const increment_start = self.currentChunk().code.items.len;

            try self.expression();
            try self.emitCode(.pop);

            try self.emitLoop(loop_start);
            loop_start = increment_start;
            try self.patchJump(body_jump);
        }

        self.consume(.left_brace, "Expected '{' before for body.");

        try self.beginScope();
        try self.block();
        try self.endScope();

        try self.emitLoop(loop_start);

        if (exit_jump) |jump| {
            try self.patchJump(jump);
            try self.emitCode(.pop);
        }

        try self.endScope(); // for scoping variables in initializer
    }

    fn statement(self: *Compiler) !void {
        if (self.match(.k_var)) {
            try self.variableDeclaration();
            return;
        }

        if (self.match(.k_print)) {
            try self.statement_print();
        } else if (self.match(.left_brace)) {
            try self.beginScope();
            try self.block();
            try self.endScope();
        } else if (self.match(.k_if)) {
            try self.statementIf();
        } else if (self.match(.k_while)) {
            try self.statementWhile();
        } else if (self.match(.k_for)) {
            try self.statementFor();
        } else if (self.match(.k_fun)) {
            try self.funDeclaration();
        } else {
            try self.expressionStatement();
        }

        if (self.parser.in_panic_mode) {
            self.synchronize();
        }
    }

    fn variableDeclaration(self: *Compiler) !void {
        const global_var_idx = try self.parseVariable("Expected variable name.");

        if (self.match(.equal)) {
            try self.expression();
        } else {
            try self.emitCode(.nil);
        }
        self.consume(.semicolon, "Expected ';' after variable declaration.");

        try self.defineVariable(global_var_idx);
    }

    fn funDeclaration(self: *Compiler) !void {
        const global = try self.parseVariable("Expected function name.");
        self.markInitialized();

        try self.compileFunction(.function);
        try self.defineVariable(global);
    }

    fn expressionStatement(self: *Compiler) !void {
        try self.expression();
        self.consume(.semicolon, "Expected ';' after expression.");
        try self.emitCode(.pop);
    }

    fn parseVariable(self: *Compiler, error_message: []const u8) !usize {
        self.consume(.identifier, error_message);

        try self.declareVariable();

        if (self.func_context.locals_info.scope_depth > 0) {
            return 0;
        }

        return try self.identifierConstant(self.parser.previous);
    }

    fn declareVariable(self: *Compiler) !void {
        // If the scope depth is zero, then this is a global variable.
        // Global variables are late bound and hence have different logic
        // for declaring them/
        if (self.func_context.locals_info.scope_depth == 0) {
            return;
        }
        const name = self.parser.previous;
        try self.addLocal(name);
    }

    fn addLocal(self: *Compiler, name: Token) !void {
        try self.func_context.locals_info.locals.append(self.allocator, .{
            .name = name,
            // null represents uninitialized
            .depth = null,
        });
    }

    fn defineVariable(self: *Compiler, global_var_idx: usize) !void {
        // If the scope depth is greater than zero, then we are defining a
        // local variable. In that case we exit the function the function early
        // before we emit the code used for definining a global variable.
        if (self.func_context.locals_info.scope_depth > 0) {
            self.markInitialized();
            return;
        }

        try self.emitCodeAndOperand(.define_global, @intCast(global_var_idx));
    }

    fn markInitialized(self: *Compiler) void {
        if (self.func_context.locals_info.scope_depth == 0) {
            return;
        }
        // Locals start out with their scope set to `null` meaning it is uninitialized.
        // Setting the depth to the current scope depth signals that the local is ready.
        self.func_context.locals_info.locals.items[self.func_context.locals_info.locals.items.len - 1].depth = self.func_context.locals_info.scope_depth;
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

    fn emitJump(self: *Compiler, code: OpCode) !usize {
        try self.emitCode(code);
        try self.emitByte(0xff);
        try self.emitByte(0xff);

        return self.currentChunk().code.items.len - 2;
    }

    fn emitLoop(self: *Compiler, loop_start: usize) !void {
        try self.emitCode(.loop);

        const code_list = &self.currentChunk().code;

        const offset = code_list.items.len - loop_start + 2;

        if (offset > std.math.maxInt(u16)) {
            self.markError("Loop body too large.");
        }

        // Fill in the 2 byte operand for the .loop op code.
        try self.emitByte(0);
        try self.emitByte(0);

        const target_bytes = code_list.items[code_list.items.len - 2 ..][0..2];
        std.mem.writeInt(u16, target_bytes, @intCast(offset), .big);
    }

    fn patchJump(self: *Compiler, offset: usize) !void {
        const jump: u16 = @intCast(self.currentChunk().code.items.len - offset - 2);

        if (jump > std.math.maxInt(u16)) {
            self.markError("Jump offset is too large.");
        }

        const target_bytes = self.currentChunk().code.items[offset..][0..2];
        std.mem.writeInt(u16, target_bytes, jump, .big);
    }

    fn emitCodeAndOperand(self: *Compiler, code: OpCode, operand: CodeContent) !void {
        try self.emitCode(code);
        try self.emitByte(operand);
    }

    fn beginScope(self: *Compiler) !void {
        self.func_context.locals_info.scope_depth += 1;
    }

    fn endScope(self: *Compiler) !void {
        self.func_context.locals_info.scope_depth -= 1;

        // Walk backwards through the local variable array and discard them.
        while (self.func_context.locals_info.locals.items.len > 0) {
            const next_local = self.func_context.locals_info.locals.getLast();

            if (next_local.depth != null and next_local.depth.? > self.func_context.locals_info.scope_depth) {
                try self.emitCode(.pop);
                _ = self.func_context.locals_info.locals.pop();
            } else {
                break;
            }
        }
    }

    fn finish(self: *Compiler) !*ObjFunction {
        try self.emitReturn();

        const function = self.func_context.curr_function;

        if (self.config.dissasemble_chunk_at_end) {
            if (!self.parser.had_error) {
                self.currentChunk().disassemble(function.get_name());
            }
        }
        return function;
    }

    fn number(self: *Compiler, _: ParseContext) !void {
        const value = Value.fromNumber(try std.fmt.parseFloat(f64, self.parser.previous.text_ref));
        try self.emitConstant(value);
    }

    fn compileFunction(self: *Compiler, kind: FunctionKind) !void {
        var nested_func_context = try FunctionCompiler.init(self.allocator, kind, self.func_context);
        defer nested_func_context.deinit();

        nested_func_context.curr_function.name = try self.alloc_monitor.createOrGetInternedObjString(self.parser.previous.text_ref);

        const parent_func_context = self.func_context;
        self.func_context = &nested_func_context;

        try self.beginScope(); // no need to close this scope since we end (.finish) the compiler later

        self.consume(.left_paren, "Expected '(' after function name.");

        // Gather parameter names and make them local variables in the function.
        if (!self.check(.right_paren)) {
            while (true) {
                self.func_context.curr_function.arity += 1;

                if (self.func_context.curr_function.arity > 255) {
                    self.markErrorAtCurrent("A function cannot have more than 255 parameters.");
                }
                const const_idx = try self.parseVariable("Expected parameter name.");
                try self.defineVariable(const_idx);

                if (!self.match(.comma)) {
                    break;
                }
            }
        }

        self.consume(.right_paren, "Expected ')' after function name.");
        self.consume(.left_brace, "Expected '{' after function name.");
        try self.block();

        const function = try self.finish();

        // Restore enclosing context.
        self.func_context = parent_func_context;

        try self.emitCodeAndOperand(.constant, try self.makeConstant(Value.fromObj(function.as_obj())));
    }

    fn and_(self: *Compiler, _: ParseContext) !void {
        const endJump = try self.emitJump(.jump_if_false);

        try self.emitCode(.pop);
        try self.parseWithPrecedence(.p_and);

        try self.patchJump(endJump);
    }

    fn or_(self: *Compiler, _: ParseContext) !void {
        const elseJump = try self.emitJump(.jump_if_false);
        const endJump = try self.emitJump(.jump);

        try self.patchJump(elseJump);
        try self.emitCode(.pop);

        try self.parseWithPrecedence(.p_or);
        try self.patchJump(endJump);
    }

    fn string(self: *Compiler, _: ParseContext) !void {
        const string_data = self.parser.previous.text_ref[1 .. self.parser.previous.text_ref.len - 1];
        const obj_string = try self.alloc_monitor.createOrGetInternedObjString(string_data);

        try self.emitConstant(Value.fromObj(@ptrCast(obj_string)));
    }

    fn variable(self: *Compiler, ctx: ParseContext) !void {
        try self.namedVariable(self.parser.previous, ctx);
    }

    fn namedVariable(self: *Compiler, name: Token, ctx: ParseContext) !void {
        var arg_idx = self.resolveLocal(name);

        const result: OpPair = if (arg_idx != null) blk: {
            break :blk .{ .get = .get_local, .set = .set_local };
        } else blk: {
            arg_idx = try self.identifierConstant(name);
            break :blk .{ .get = .get_global, .set = .set_global };
        };

        if (ctx.can_assign and self.match(.equal)) {
            try self.expression();
            try self.emitCodeAndOperand(result.set, @intCast(arg_idx.?));
        } else {
            try self.emitCodeAndOperand(result.get, @intCast(arg_idx.?));
        }
    }

    fn resolveLocal(self: *Compiler, name: Token) ?usize {
        var i: usize = self.func_context.locals_info.locals.items.len;
        while (i > 0) {
            i -= 1;
            const local = self.func_context.locals_info.locals.items[i];

            // Return the local's index if the requested name matches.
            // We need to compare the strings by value since these are pointers into
            // the original source string, rather than interned strings that we can
            // compare by pointer.
            if (std.mem.eql(u8, name.text_ref, local.name.text_ref)) {
                if (local.depth == null) {
                    self.markError("Cannot ready local variable in its own initialzer.");
                    // Should we return here?
                }

                return i;
            }
        }
        return null;
    }

    fn unary(self: *Compiler, _: ParseContext) !void {
        const prev_kind = self.parser.previous.kind;

        // Compile the operand of the unary expression.
        try self.parseWithPrecedence(.unary);

        switch (prev_kind) {
            .minus => try self.emitCode(.negate),
            .bang => try self.emitCode(.not),
            else => unreachable,
        }
    }

    fn binary(self: *Compiler, _: ParseContext) !void {
        const op_kind = self.parser.previous.kind;
        const rule = self.getRule(op_kind);

        try self.parseWithPrecedence(rule.precedence.withOneMoreBindingPower());

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

    fn literal(self: *Compiler, _: ParseContext) !void {
        const op_kind = self.parser.previous.kind;

        switch (op_kind) {
            .k_false => try self.emitCode(.code_false),
            .k_nil => try self.emitCode(.nil),
            .k_true => try self.emitCode(.code_true),
            else => unreachable,
        }
    }

    fn parseWithPrecedence(self: *Compiler, precedence: Precendence) !void {
        self.advance();

        const prefix_rule = self.getRule(self.parser.previous.kind).prefix;

        if (prefix_rule == null) {
            self.markError("Expect expression");
            return;
        }
        const can_assign = precedence.hasLessOrEqBindingPowerThan(.assignment);
        try prefix_rule.?(self, .{ .can_assign = can_assign });

        while (precedence.hasLessOrEqBindingPowerThan(self.getRule(self.parser.current.kind).precedence)) {
            self.advance();

            const infix_rule = self.getRule(self.parser.previous.kind).infix;

            try infix_rule.?(self, .{ .can_assign = can_assign });
        }

        if (can_assign and self.match(.equal)) {
            self.markError("Invalid assignment target.");
        }
    }

    fn grouping(self: *Compiler, _: ParseContext) !void {
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
        _ = self;
    }
};

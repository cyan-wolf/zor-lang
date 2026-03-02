const std = @import("std");
const Allocator = std.mem.Allocator;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const CodeContent = chunk_mod.CodeContent;
const OpCode = chunk_mod.OpCode;
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const Obj = value_mod.Obj;
const ObjString = value_mod.ObjString;
const table_mod = @import("table.zig");
const TableContext = table_mod.TableContext;
const StringPool = table_mod.StringPool;

const Cli = @import("cli.zig").Cli;
const Compiler = @import("compiler.zig").Compiler;

pub const DEBUG_TRACE_EXECUTION = true;

pub const InterpretError = error{
    CompileError,
    RuntimeError,
};

pub const AllocMonitor = struct {
    objects: ?*Obj,
    interned_strings: StringPool,
    table_context: TableContext,
    allocator: Allocator,

    pub fn init(allocator: std.mem.Allocator) AllocMonitor {
        return .{
            .objects = null,
            .interned_strings = StringPool.init(allocator),
            .table_context = .{},
            .allocator = allocator,
        };
    }

    pub fn createOrGetInternedObjString(self: *AllocMonitor, data: []const u8) !*ObjString {
        // If the string has already been interned, just returned the cached pointer.
        if (self.interned_strings.getKeyAdapted(data, self.table_context)) |ptr| {
            return ptr;
        }
        // Otherwise, allocate a new string out of the bytes in `data`.
        const string = try ObjString.cloneString(self.allocator, data);
        try self.registerAllocatedObj(string.as_obj());

        // Mark the string as being interned.
        try self.interned_strings.put(string, {});

        return string;
    }

    fn registerAllocatedObj(self: *AllocMonitor, obj: *Obj) !void {
        obj.next = self.objects;
        self.objects = obj;
    }

    pub fn deinit(self: *AllocMonitor) void {
        var curr = self.objects;

        while (curr != null) {
            defer curr.?.deinit(self.allocator);
            curr = curr.?.next;
        }
        self.interned_strings.deinit();
    }
};

pub const VM = struct {
    chunk: ?*Chunk,
    ip: usize,
    stack: std.ArrayList(Value),
    alloc_monitor: AllocMonitor,

    allocator: Allocator,
    cli: Cli,
    compiler: ?Compiler,

    pub fn init(allocator: Allocator, cli: Cli) VM {
        return .{
            .chunk = null,
            .ip = 0,
            .stack = .empty,
            .alloc_monitor = AllocMonitor.init(allocator),

            .allocator = allocator,
            .cli = cli,
            .compiler = null,
        };
    }

    pub fn interpret(self: *VM, source: []const u8) !void {
        var chunk = Chunk.init();
        defer chunk.deinit(self.allocator);

        self.chunk = &chunk;
        self.ip = 0;

        // NOTE: This might not have to be a field of VM.
        self.compiler = Compiler.init(source, self.allocator, self.alloc_monitor);

        const couldCompile = try self.compiler.?.compile(&chunk);
        if (!couldCompile) {
            return error.CompileError;
        }

        try self.run();
    }

    fn peek(self: *const VM, distance: usize) Value {
        return self.stack.items[self.stack.items.len - 1 - distance];
    }

    fn push(self: *VM, value: Value) !void {
        try self.stack.append(self.allocator, value);
    }

    fn pop(self: *VM) Value {
        return self.stack.pop() orelse unreachable;
    }

    fn readByte(self: *VM) CodeContent {
        const content = self.chunk.?.code.items[self.ip];
        self.ip += 1;
        return content;
    }

    // Note: We assume that the current byte is a valid op code.
    fn readCode(self: *VM) OpCode {
        return @enumFromInt(self.readByte());
    }

    fn readConstant(self: *VM) Value {
        const constantIdx = self.readByte();
        return self.chunk.?.constants.items[constantIdx];
    }

    inline fn binaryOp(self: *VM, comptime op: enum { add, sub, mul, div, less, greater }) !void {
        if (!self.peek(0).isNumber() or !self.peek(1).isNumber()) {
            try self.reportRuntimeError("Operands must be numbers");
        }

        const b = self.pop().asNumber();
        const a = self.pop().asNumber();

        try self.push(switch (op) {
            .add => Value.fromNumber(a + b),
            .sub => Value.fromNumber(a - b),
            .mul => Value.fromNumber(a * b),
            .div => Value.fromNumber(a / b),
            .less => Value.fromBoolean(a < b),
            .greater => Value.fromBoolean(a > b),
        });
    }

    pub fn concatenate(self: *VM) !void {
        const b = self.pop().asString();
        const a = self.pop().asString();

        const concat_data: []const u8 = try std.mem.concat(self.allocator, u8, &[_][]const u8{ a.data, b.data });
        // We free this memory in this function since the cloneString
        // function will just copy the memory anyways. Not freeing here would
        // lead to a memory leak.
        defer self.allocator.free(concat_data);

        const string = try self.alloc_monitor.createOrGetInternedObjString(concat_data);
        try self.push(Value.fromObj(string.as_obj()));
    }

    fn run(self: *VM) !void {
        while (true) {
            if (DEBUG_TRACE_EXECUTION) {
                // Print the stack.
                std.debug.print("        ", .{});
                for (self.stack.items) |slot| {
                    std.debug.print("[ ", .{});
                    slot.show();
                    std.debug.print(" ]", .{});
                }
                std.debug.print("\n", .{});

                // Print the current instruction.
                _ = self.chunk.?.disassembleInstruction(self.ip);
            }

            // The instruction pointer should always end up pointing to
            // a valid op code at the start of a run loop.
            const instruction = self.readCode();

            switch (instruction) {
                .opreturn => {
                    self.pop().show();
                    std.debug.print("\n", .{});
                    return;
                },
                .constant => {
                    const constant = self.readConstant();
                    try self.push(constant);
                },
                .nil => try self.push(Value.fromNil()),
                .code_true => try self.push(Value.fromBoolean(true)),
                .code_false => try self.push(Value.fromBoolean(false)),
                .equal => {
                    const b = self.pop();
                    const a = self.pop();

                    try self.push(Value.fromBoolean(a.equals(b)));
                },
                .negate => {
                    switch (self.peek(0)) {
                        .number => |n| try self.push(Value.fromNumber(-n)),
                        else => try self.reportRuntimeError("operand must be a number"),
                    }
                },
                .greater => try self.binaryOp(.greater),
                .less => try self.binaryOp(.less),
                .add => {
                    if (self.peek(0).isString() and self.peek(1).isString()) {
                        try self.concatenate();
                    } else if (self.peek(0).isNumber() and self.peek(1).isNumber()) {
                        try self.binaryOp(.add);
                    } else {
                        try self.reportRuntimeError("Operands must be two numbers or two strings.");
                    }
                },
                .subtract => try self.binaryOp(.sub),
                .multiply => try self.binaryOp(.mul),
                .divide => try self.binaryOp(.div),
                .not => try self.push(Value.fromBoolean(self.pop().isFalsey())),
            }
        }
    }

    pub fn repl(self: *VM) !void {
        while (true) {
            const line = try self.cli.input("> ");
            try self.interpret(line);
        }
    }

    pub fn runFile(self: *VM, filename: []const u8) !void {
        const OOM_SAFETY_LIMIT = 10 * 1024 * 1024;

        const content = try std.fs.cwd().readFileAlloc(self.allocator, filename, OOM_SAFETY_LIMIT);
        defer self.allocator.free(content);

        self.interpret(content) catch |err| switch (err) {
            error.CompileError => std.process.exit(65),
            error.RuntimeError => std.process.exit(70),
            error.OutOfMemory => std.process.exit(1),
            error.InvalidCharacter => std.process.exit(1),
        };
    }

    fn reportRuntimeError(self: *VM, message: []const u8) !void {
        const instructionIdx = self.ip;
        const line = self.chunk.?.lines.items[instructionIdx];

        std.debug.print("{s} [line {d}] in script\n", .{ message, line });

        // Reset the stack.
        self.stack.clearAndFree(self.allocator);

        return error.RuntimeError;
    }

    pub fn deinit(self: *VM) void {
        self.alloc_monitor.deinit();

        self.chunk = null;
        self.stack.deinit(self.allocator);
    }
};

const std = @import("std");
const Allocator = std.mem.Allocator;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const CodeContent = chunk_mod.CodeContent;
const OpCode = chunk_mod.OpCode;
const Value = chunk_mod.Value;

fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}

pub const DEBUG_TRACE_EXECUTION = true;

pub const InterpretError = error {
    CompileError,
    RuntimeError,
};

pub const VM = struct {
    chunk: ?*Chunk,
    ip: usize,
    allocator: Allocator,
    stack: std.ArrayList(Value),

    pub fn init(allocator: Allocator) VM {
        return .{
            .chunk = null,
            .ip = 0,
            .allocator = allocator,
            .stack = .empty,
        };
    }

    pub fn interpret(self: *VM, chunk: *Chunk) !void {
        self.chunk = chunk;
        self.ip = 0;

        try self.run();
    }

    fn peek(self: *const VM) Value {
        return self.stack.items[self.stack.items.len];
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

    fn run(self: *VM) !void {
        while (true) {
            if (DEBUG_TRACE_EXECUTION) {
                // Print the stack.
                std.debug.print("        ", .{});
                for (self.stack.items) |slot| {
                    std.debug.print("[ ", .{});
                    printValue(slot);
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
                    printValue(self.pop());
                    std.debug.print("\n", .{});
                    return;
                },
                .constant => {
                    const constant = self.readConstant();
                    try self.push(constant);
                    break;
                },
            }
        }
    }

    pub fn deinit(self: *VM) void {
        self.chunk = null;
        self.stack.deinit(self.allocator);
    }
};
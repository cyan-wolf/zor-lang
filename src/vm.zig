const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const CodeContent = chunk_mod.CodeContent;
const OpCode = chunk_mod.OpCode;
const Value = chunk_mod.Value;

fn printValue(value: Value) void {
    std.debug.print("{d}", .{value});
}

pub const InterpretError = error {
    CompileError,
    RuntimeError,
};

pub const VM = struct {
    chunk: ?*Chunk,
    ip: usize,

    pub fn init() VM {
        return .{
            .chunk = null,
            .ip = 0,
        };
    }

    pub fn interpret(self: *VM, chunk: *Chunk) !void {
        self.chunk = chunk;
        self.ip = 0;

        try self.run();
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
            // The instruction pointer should always end up pointing to 
            // a valid op code at the start of a run loop.
            const instruction = self.readCode();

            switch (instruction) {
                .opreturn => {
                    return;
                },
                .constant => {
                    const constant = self.readConstant();

                    printValue(constant);

                    std.debug.print("\n", .{});

                    break;
                },
            }
        }
    }

    pub fn deinit(self: *VM) void {
        self.chunk = null;
    }
};
const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const CodeContent = chunk_mod.CodeContent;
const OpCode = chunk_mod.OpCode;

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

        self.run();
    }

    fn readByte(self: *VM) CodeContent {
        const content = self.chunk.?.code.items[self.ip];
        self.ip += 1;
        return content;
    }

    fn run(self: *VM) !void {
        while (true) {
            // The instruction pointer should always end up pointing to 
            // a valid op code at the start of a run loop.
            const instruction: OpCode = @enumFromInt(self.readByte());

            switch (instruction) {
                .opreturn => {
                    return;
                },
            }
        }
    }

    pub fn deinit(self: *VM) void {
        self.chunk = null;
    }
};
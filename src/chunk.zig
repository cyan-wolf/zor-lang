const std = @import("std");
const Allocator = std.mem.Allocator;

pub const OpCode = enum(u8) {
    opreturn,

    pub fn asString(self: OpCode) []const u8 {
        return switch (self) {
            .opreturn => "OP_RETURN",
        };
    }
};

pub const ChunkPayload = OpCode;

const ChunkList = std.ArrayList(ChunkPayload);

pub const Chunk = struct {
    code: ChunkList,

    pub fn init() Chunk {
        return .{
            .code = .empty,
        };
    }

    pub fn write(self: *Chunk, allocator: Allocator, byte: ChunkPayload) !void {
        try self.code.append(allocator, byte);
    }

    pub fn deinit(self: *Chunk, allocator: Allocator) void {
        self.code.deinit(allocator);
    }

    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        // Print a header to identify the chunk.
        std.debug.print("== {s} == \n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            // Re-assign the offset depending on how the instruction was 
            // processed since different instructions can have different sizes.
            offset = self.disassembleInstruction(offset);
        }
    }

    fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
        std.debug.print("{d:0>4} ", .{offset});

        const instruction = self.code.items[offset];
        std.debug.print("{s}\n", .{instruction.asString()});

        // All current instructions are one byte long.
        return offset + 1;
    }
};

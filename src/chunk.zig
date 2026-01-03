const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ChunkPayload = u8;

pub const OpCode = enum(ChunkPayload) {
    opreturn,
};

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
};

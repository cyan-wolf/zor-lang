const std = @import("std");
const Allocator = std.mem.Allocator;

pub const ChunkPayload = u8;

pub const OpCode = enum(ChunkPayload) {
    opreturn,
};

pub const Chunk = struct {
    code: std.ArrayList(ChunkPayload),

    pub fn init(allocator: Allocator) Chunk {
        return .{
            .code = std.ArrayList(ChunkPayload).init(allocator),
        };
    }

    pub fn write(self: *const Chunk, allocator: Allocator, byte: ChunkPayload) !void {
        try self.code.append(allocator, byte);
    }

    pub fn deinit(self: *const Chunk, allocator: Allocator) !void {
        try self.code.deinit(allocator);
    }
};

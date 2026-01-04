const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;

pub fn main() !void {
    std.debug.print("Hello World\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {

        // Deinit the allocator and check for memory leaks.
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected.");
        }
    }

    const allocator = gpa.allocator();

    // Sample chunk code.
    var c = Chunk.init();
    defer c.deinit(allocator);

    const constIdx = try c.addConstant(allocator, 1.2);
    try c.write(allocator, @intFromEnum(OpCode.constant));
    try c.write(allocator, @intCast(constIdx));

    try c.write(allocator, @intFromEnum(OpCode.opreturn));

    c.disassemble("test chunk");
}

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
    try c.write(allocator, .opreturn);

    c.disassemble("test chunk");
}

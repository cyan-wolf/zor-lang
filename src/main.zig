const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const VM = @import("vm.zig").VM;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        // Deinit the allocator and check for memory leaks.
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected.");
        }
    }

    const allocator = gpa.allocator();

    var vm = VM.init(allocator);
    defer vm.deinit();

    // Sample chunk code.
    var c = Chunk.init();
    defer c.deinit(allocator);

    // Add the 1.2 constant.
    const constIdx = try c.addConstant(allocator, 1.2);
    try c.write(allocator, @intFromEnum(OpCode.constant), 12);
    try c.write(allocator, @intCast(constIdx), 123);
    
    const idx1 = try c.addConstant(allocator, 3.4);
    try c.write(allocator, @intFromEnum(OpCode.constant), 123);
    try c.write(allocator, @intCast(idx1), 123);

    try c.write(allocator, @intFromEnum(OpCode.add), 123);

    // Add the 5.6 constant.
    const idx2 = try c.addConstant(allocator, 5.6);
    try c.write(allocator, @intFromEnum(OpCode.constant), 123);
    try c.write(allocator, @intCast(idx2), 123);
    
    try c.write(allocator, @intFromEnum(OpCode.divide), 123);
    try c.write(allocator, @intFromEnum(OpCode.negate), 123);

    try c.write(allocator, @intFromEnum(OpCode.opreturn), 12);

    // c.disassemble("test chunk");

    try vm.interpret(&c);
}

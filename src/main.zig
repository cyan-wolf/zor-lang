const std = @import("std");
const zor_lang = @import("zor_lang");

pub fn main() !void {
    std.debug.print("Hello World");

    const gpa = std.heap.GeneralPurposeAllocator(.{}){};

    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            @panic("Memory leak detected.");
        }
    }

    const allocator = gpa.allocator();

    // TODO: actually use the allocator
    _ = allocator;
}

const std = @import("std");
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const vm_mod = @import("vm.zig");
const VM = vm_mod.VM;
const ZorConfig = vm_mod.ZorConfig;
const Cli = @import("cli.zig").Cli;

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

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var out_buf: [1024]u8 = undefined;
    var in_buf: [1024]u8 = undefined;

    const cli = Cli.init(&out_buf, &in_buf);

    // TODO: read this from command line arguments.
    const config: ZorConfig = .{
        .trace_execution = false,
        .trace_parser_advance = false,
    };

    var vm = try VM.init(
        allocator,
        cli,
        config,
    );
    defer vm.deinit();

    if (args.len == 1) {
        try vm.repl();
    } else if (args.len == 2) {
        try vm.runFile(args[1]);
    } else {
        std.debug.print("Usage: zor [path]\n", .{});
        std.process.exit(64);
    }
}

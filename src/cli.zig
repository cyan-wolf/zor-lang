const std = @import("std");

pub const Cli = struct {
    out_wrap: std.fs.File.Writer,
    in_wrap: std.fs.File.Reader,

    pub fn init(out_buf: []u8, in_buf: []u8) Cli {
        return .{
            .out_wrap = std.fs.File.stdout().writer(out_buf),
            .in_wrap = std.fs.File.stdin().reader(in_buf),
        };
    }

    pub fn input(self: *Cli, prompt: []const u8) ![]const u8 {
        var stdout = &self.out_wrap.interface;
        var stdin = &self.in_wrap.interface;

        try stdout.writeAll(prompt);
        try stdout.flush();

        const line = try stdin.takeDelimiterExclusive('\n');

        stdin.toss(1);
        return std.mem.trimRight(u8, line, "\r");
    }
};

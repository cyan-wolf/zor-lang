const Scanner = @import("scanner.zig").Scanner;

pub const Compiler = struct {
    source: []const u8,
    scanner: Scanner,

    pub fn init(source: []const u8) Compiler {
        return .{
            .source = source,
            .scanner = Scanner.init(source),
        };
    }

    pub fn compile(self: *Compiler) !void {
        _ = self;
    }
};

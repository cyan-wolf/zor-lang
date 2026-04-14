const std = @import("std");
const Token = @import("token.zig").Token;

pub const Local = struct {
    name: Token,
    depth: ?usize,
};

pub const LocalsInfo = struct {
    locals: std.ArrayList(Local) = .empty,
    scope_depth: usize = 0,

    pub fn deinit(self: *LocalsInfo, allocator: std.mem.Allocator) void {
        self.locals.deinit(allocator);
    }
};

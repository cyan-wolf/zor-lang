const std = @import("std");
const Token = @import("token.zig").Token;

pub const Local = struct {
    name: Token,
    depth: ?usize,
};

pub const LocalsInfo = struct {
    locals: std.ArrayList(Local),
    scope_depth: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !LocalsInfo {
        // See: https://craftinginterpreters.com/calls-and-functions.html#creating-functions-at-compile-time.
        var locals: std.ArrayList(Local) = .empty;
        const local_var_slot_used_by_vm: Local = .{
            .depth = 0,
            .name = .createDummyInitialToken(),
        };

        try locals.append(allocator, local_var_slot_used_by_vm);

        return .{
            .locals = locals,
        };
    }

    pub fn deinit(self: *LocalsInfo, allocator: std.mem.Allocator) void {
        self.locals.deinit(allocator);
    }
};

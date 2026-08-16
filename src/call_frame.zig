const value_mod = @import("value.zig");
const Value = value_mod.Value;
const ObjClosure = @import("obj.zig").ObjClosure;

pub const CallFrame = struct {
    closure: *ObjClosure,
    ip: usize,
    stack_start_idx: usize,
};

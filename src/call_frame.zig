const value_mod = @import("value.zig");
const Value = value_mod.Value;
const ObjFunction = value_mod.ObjFunction;

pub const CallFrame = struct {
    function: *ObjFunction,
    ip: usize,
    stack_start_idx: usize,
};

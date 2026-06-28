const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;

pub fn nativeFunctionClock(arg_count: usize, args: []const Value) !Value {
    _ = arg_count;
    _ = args;

    const elapsed_secs_since_unix_epoch = std.time.milliTimestamp();
    const elapsed_float: f64 = @floatFromInt(elapsed_secs_since_unix_epoch);

    return Value.fromNumber(elapsed_float);
}

const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const AllocMonitor = @import("vm.zig").AllocMonitor;

pub fn nativeFunctionClock(arg_count: usize, args: []const Value, alloc_monitor: *AllocMonitor) !Value {
    _ = arg_count;
    _ = args;
    _ = alloc_monitor;

    const elapsed_millisecs_since_unix_epoch = std.time.milliTimestamp();
    const elapsed_float: f64 = @floatFromInt(elapsed_millisecs_since_unix_epoch);

    return Value.fromNumber(elapsed_float);
}

pub fn nativeFunctionGetType(arg_count: usize, args: []const Value, alloc_monitor: *AllocMonitor) !Value {
    _ = arg_count;

    const arg_type_name = args[0].getTypeString();
    const string = try alloc_monitor.createOrGetInternedObjString(arg_type_name);
    return Value.fromObj(string.as_obj());
}

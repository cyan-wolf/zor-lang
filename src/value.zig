const std = @import("std");
const hashString = @import("table.zig").hashString;
const Chunk = @import("chunk.zig").Chunk;
const AllocMonitor = @import("vm.zig").AllocMonitor;
const obj_mod = @import("obj.zig");
const Obj = obj_mod.Obj;
const ObjString = obj_mod.ObjString;
const ObjFunction = obj_mod.ObjFunction;
const ObjClosure = obj_mod.ObjClosure;
const ObjNativeFunction = obj_mod.ObjNativeFunction;

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    nil: void,
    obj: *Obj,

    pub fn fromNumber(n: f64) Value {
        return .{ .number = n };
    }

    pub fn fromBoolean(b: bool) Value {
        return .{ .boolean = b };
    }

    pub fn fromNil() Value {
        return .{ .nil = {} };
    }

    pub fn fromObj(o: *Obj) Value {
        return .{ .obj = o };
    }

    pub fn asNumber(self: Value) f64 {
        return switch (self) {
            .number => |n| n,
            else => unreachable,
        };
    }

    pub fn isNumber(self: Value) bool {
        return switch (self) {
            .number => true,
            else => false,
        };
    }

    pub fn asString(self: Value) *ObjString {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .string => o.as_obj_string_mut(),
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub fn asFunction(self: Value) *ObjFunction {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .function => o.as_obj_function_mut(),
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub fn asClosure(self: Value) *ObjClosure {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .closure => o.as_obj_closure_mut(),
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub fn asNativeFunction(self: Value) *ObjNativeFunction {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .native_function => o.as_obj_native_function_mut(),
                else => unreachable,
            },
            else => unreachable,
        };
    }

    pub fn isString(self: Value) bool {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .string => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isFunction(self: Value) bool {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .function => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isClosure(self: Value) bool {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .closure => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isNativeFunction(self: Value) bool {
        return switch (self) {
            .obj => |o| switch (o.kind) {
                .native_function => true,
                else => false,
            },
            else => false,
        };
    }

    pub fn isFalsey(self: Value) bool {
        return switch (self) {
            .boolean => |b| !b,
            .nil => true,
            else => false,
        };
    }

    pub fn equals(self: Value, other: Value) bool {
        return switch (self) {
            .boolean => |b1| switch (other) {
                .boolean => |b2| b1 == b2,
                else => false,
            },
            .nil => switch (other) {
                .nil => true,
                else => false,
            },
            .number => |n1| switch (other) {
                .number => |n2| n1 == n2,
                else => false,
            },
            .obj => |o1| switch (other) {
                .obj => |o2| o1.is_equal(o2),
                else => false,
            },
        };
    }

    pub fn show(self: Value) void {
        switch (self) {
            .boolean => |b| std.debug.print("{}", .{b}),
            .nil => std.debug.print("nil", .{}),
            .number => |n| std.debug.print("{d}", .{n}),
            .obj => |o| o.show(),
        }
    }

    // Used by, for example, `print`.
    // Currently only strings have a different pretty print representation.
    pub fn show_pretty(self: Value) void {
        switch (self) {
            .obj => |o| o.show_pretty(),
            else => self.show(),
        }
    }

    pub fn getTypeString(self: Value) []const u8 {
        switch (self) {
            .obj => |o| {
                return @tagName(o.kind);
            },
            else => {
                return @tagName(self);
            },
        }
    }
};

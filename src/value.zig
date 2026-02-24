const std = @import("std");

pub const Value = union(enum) {
    number: f64,
    boolean: bool,
    nil: void,

    pub fn fromNumber(n: f64) Value {
        return .{ .number = n };
    }

    pub fn fromBoolean(b: bool) Value {
        return .{ .boolean = b };
    }

    pub fn fromNil() Value {
        return .{ .nil = {} };
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
        };
    }

    pub fn show(self: Value) void {
        switch (self) {
            .boolean => |b| std.debug.print("{}", .{b}),
            .nil => std.debug.print("nil", .{}),
            .number => |n| std.debug.print("{d}", .{n}),
        }
    }
};
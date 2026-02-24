const std = @import("std");

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
};

pub const ObjKind = enum {
    string,
};

pub const Obj = struct {
    kind: ObjKind,

    pub fn is_equal(self: *const Obj, other: *const Obj) bool {
        switch (self.kind) {
            .string => switch (other.kind) {
                .string => {
                    const o1 = self.as_obj_string_const();
                    const o2 = other.as_obj_string_const();

                    return std.mem.eql(u8, o1.data, o2.data);
                },
            },
        }
    }

    pub fn show(self: *const Obj) void {
        switch (self.kind) {
            .string => {
                const obj_string = self.as_obj_string_const();
                std.debug.print("[object string '{s}']", .{obj_string.data});
            },
        }
    }

    fn as_obj_string_const(self: *const Obj) *const ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }
};

pub const ObjString = struct {
    obj: Obj,
    data: []const u8,

    // Used for allocating string literals onto the heap.
    pub fn cloneString(allocator: std.mem.Allocator, string_data: []const u8) !*ObjString {
        const new_string_data = try allocator.dupe(u8, string_data);

        const ptr = try allocator.create(ObjString);
        ptr.* = .{
            .obj = .{
                .kind = .string,
            },
            .data = new_string_data,
        };

        return ptr;
    }
};

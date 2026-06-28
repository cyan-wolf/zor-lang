const std = @import("std");
const hashString = @import("table.zig").hashString;
const Chunk = @import("chunk.zig").Chunk;

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
};

pub const ObjKind = enum {
    string,
    function,
};

pub const Obj = struct {
    kind: ObjKind,
    next: ?*Obj,

    pub fn is_equal(self: *const Obj, other: *const Obj) bool {
        switch (self.kind) {
            .string => switch (other.kind) {
                .string => {
                    const o1 = self.as_obj_string_const();
                    const o2 = other.as_obj_string_const();

                    // All strings are interned, so we can just compare
                    // by pointer equality (==) instead of character-by-character
                    // (std.mem.eql).
                    return o1 == o2;
                },
                else => return false,
            },
            .function => switch (other.kind) {
                .function => {
                    const o1 = self.as_obj_function_const();
                    const o2 = other.as_obj_function_const();

                    // Pointer equality.
                    return o1 == o2;
                },
                else => return false,
            },
        }
    }

    pub fn show(self: *const Obj) void {
        switch (self.kind) {
            .string => {
                const obj_string = self.as_obj_string_const();
                std.debug.print("[object string '{s}']", .{obj_string.data});
            },
            .function => {
                const name: []const u8 = self.as_obj_function_const().get_name();
                std.debug.print("<fn {s}>", .{name});
            },
        }
    }

    // Representation in `print` (for example).
    pub fn show_pretty(self: *const Obj) void {
        switch (self.kind) {
            .string => {
                const obj_string = self.as_obj_string_const();
                std.debug.print("{s}", .{obj_string.data});
            },
            else => self.show(),
        }
    }

    fn as_obj_string_mut(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    fn as_obj_string_const(self: *const Obj) *const ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    fn as_obj_function_mut(self: *Obj) *ObjFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    fn as_obj_function_const(self: *const Obj) *const ObjFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn deinit(self: *Obj, allocator: std.mem.Allocator) void {
        switch (self.kind) {
            .string => {
                const string = self.as_obj_string_mut();
                defer allocator.free(string.data);
                defer allocator.destroy(string);
            },
            .function => {
                const func = self.as_obj_function_mut();
                // TODO
                _ = func;
            },
        }
    }
};

pub const ObjString = struct {
    obj: Obj,
    data: []const u8,
    hash: u64,

    // Used for allocating string literals onto the heap.
    // WARNING: Do not use this method directly as it creates uninterned strings.
    // Instead create interned strings using the Allocation Monitor type on the VM.
    pub fn cloneStringnUninterned(allocator: std.mem.Allocator, string_data: []const u8) !*ObjString {
        // Defensively copy the data.
        const new_string_data = try allocator.dupe(u8, string_data);

        const ptr = try allocator.create(ObjString);
        ptr.* = .{
            .obj = .{
                .kind = .string,
                .next = null,
            },
            .data = new_string_data,
            .hash = hashString(new_string_data),
        };

        return ptr;
    }

    pub fn as_obj(self: *ObjString) *Obj {
        return @ptrCast(self);
    }
};

pub const ObjFunction = struct {
    obj: Obj,
    arity: usize,
    chunk: Chunk,
    name: ?*const ObjString,

    pub fn createNew(allocator: std.mem.Allocator) !*ObjFunction {
        const ptr = try allocator.create(ObjFunction);
        ptr.* = .{
            .obj = .{
                .kind = .function,
                .next = null,
            },
            .arity = 0,
            .name = null,
            .chunk = Chunk.init(),
        };

        return ptr;
    }

    pub fn get_name(self: *const ObjFunction) []const u8 {
        return if (self.name) |str| blk: {
            break :blk str.data;
        } else blk: {
            break :blk "script";
        };
    }

    pub fn as_obj(self: *ObjFunction) *Obj {
        return @ptrCast(self);
    }
};

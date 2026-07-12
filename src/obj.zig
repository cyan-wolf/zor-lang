const std = @import("std");
const hashString = @import("table.zig").hashString;
const Chunk = @import("chunk.zig").Chunk;
const AllocMonitor = @import("vm.zig").AllocMonitor;
const Value = @import("value.zig").Value;

pub const ObjKind = enum {
    string,
    function,
    native_function,
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
            .native_function => switch (other.kind) {
                .native_function => {
                    const o1 = self.as_obj_native_function_const();
                    const o2 = other.as_obj_native_function_const();

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
                std.debug.print("<fun {s}>", .{name});
            },
            .native_function => {
                std.debug.print("<native fun>", .{});
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

    pub fn as_obj_string_mut(self: *Obj) *ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn as_obj_string_const(self: *const Obj) *const ObjString {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn as_obj_function_mut(self: *Obj) *ObjFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn as_obj_function_const(self: *const Obj) *const ObjFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn as_obj_native_function_mut(self: *Obj) *ObjNativeFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn as_obj_native_function_const(self: *const Obj) *const ObjNativeFunction {
        return @alignCast(@fieldParentPtr("obj", self));
    }

    pub fn deinit(self: *Obj, allocator: std.mem.Allocator) void {
        switch (self.kind) {
            .string => {
                const string = self.as_obj_string_mut();
                allocator.free(string.data);
                allocator.destroy(string);
            },
            .function => {
                const func = self.as_obj_function_mut();
                func.chunk.deinit(allocator);
                allocator.destroy(func);
            },
            .native_function => {
                const native = self.as_obj_native_function_mut();
                allocator.destroy(native);
            },
        }
    }
};

pub const ObjString = struct {
    obj: Obj,
    data: []const u8,
    hash: u64,

    /// Used for allocating strings onto the heap.
    /// WARNING: Do not use this method directly as it creates uninterned strings.
    /// Instead create interned strings using the Allocation Monitor type on the VM.
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

    /// NOTE: Do not call this method directly, use `AllocMonitor.createFunction` instead.
    pub fn initUntracked(allocator: std.mem.Allocator) !*ObjFunction {
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

pub const NativeFunctionError = error{
    OutOfMemory,
    InvalidCharacter,
};

pub const NativeFunction = *const fn (arg_count: usize, args: []const Value, alloc_monitor: *AllocMonitor) NativeFunctionError!Value;

pub const ObjNativeFunction = struct {
    obj: Obj,
    function: NativeFunction,
    arity: usize,

    /// NOTE: Do not call this method directly, use `AllocMonitor.createNativeFunction` instead.
    pub fn initUntracked(allocator: std.mem.Allocator, function: NativeFunction, arity: usize) !*ObjNativeFunction {
        const ptr = try allocator.create(ObjNativeFunction);
        ptr.* = .{
            .obj = .{
                .kind = .native_function,
                .next = null,
            },
            .function = function,
            .arity = arity,
        };

        return ptr;
    }

    pub fn as_obj(self: *ObjNativeFunction) *Obj {
        return @ptrCast(self);
    }
};

const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const ObjString = @import("obj.zig").ObjString;

pub fn hashString(string: []const u8) u64 {
    return std.hash.Wyhash.hash(0, string);
}

pub const TableContext = struct {
    pub fn hash(_: TableContext, key: *ObjString) u64 {
        return key.hash;
    }

    pub fn eql(_: TableContext, a: *ObjString, b: *ObjString) bool {
        // Pointer equality since the (*ObjString) values are interned.
        return a == b;
    }
};

pub const StringPoolContext = struct {
    pub fn hash(_: StringPoolContext, key: anytype) u64 {
        const T = @TypeOf(key);
        return if (T == *ObjString) key.hash else hashString(key);
    }

    pub fn eql(_: StringPoolContext, a: anytype, b: anytype) bool {
        const TA = @TypeOf(a);
        const TB = @TypeOf(b);

        const s1 = if (TA == *ObjString) a.data else a;
        const s2 = if (TB == *ObjString) b.data else b;

        // Compare the actual contents so that a new string with a different
        // address but identical content is not interned twice.
        return std.mem.eql(u8, s1, s2);
    }
};

pub const Table = std.HashMap(*ObjString, Value, TableContext, std.hash_map.default_max_load_percentage);

pub const StringPool = std.HashMap(*ObjString, void, StringPoolContext, std.hash_map.default_max_load_percentage);

const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const ObjString = value_mod.ObjString;

pub fn hashString(string: []const u8) u64 {
    return std.hash.Wyhash.hash(0, string);
}

pub const TableContext = struct {
    const Self = @This();

    pub fn hash(self: Self, key: anytype) u64 {
        _ = self;

        const T = @TypeOf(key);
        if (T == *ObjString) {
            return key.hash;
        } else if (T == []const u8) {
            return hashString(key);
        } else {
            @compileError("Unsupported hash type");
        }
    }

    pub fn eql(self: Self, a: anytype, b: anytype) bool {
        _ = self;

        const TA = @TypeOf(a);
        const TB = @TypeOf(b);

        if (TA == *ObjString and TB == *ObjString) {
            // Compare by pointer equality.
            return a == b;
        }
        // If one of the arguments is a bare string ([]const u8) then
        // we compare character-by-character with std.mem.eql.
        else if (TA == []const u8 and TB == *ObjString) {
            return std.mem.eql(u8, a, b.data);
        } else if (TA == *ObjString and TB == []const u8) {
            return std.mem.eql(u8, a.data, b);
        }
        return false;
    }
};

pub const Table = std.HashMap(*ObjString, Value, TableContext, std.hash_map.default_max_load_percentage);

pub const StringPool = std.HashMap(*ObjString, void, TableContext, std.hash_map.default_max_load_percentage);

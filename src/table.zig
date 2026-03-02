const std = @import("std");
const value_mod = @import("value.zig");
const Value = value_mod.Value;
const ObjString = value_mod.ObjString;

pub fn hashString(string: []const u8) u64 {
    return std.hash.Wyhash.hash(0, string);
}

const TableContext = struct {
    const Self = @This();

    pub fn hash(self: Self, key: *ObjString) u64 {
        _ = self;
        return key.hash;
    }

    pub fn eql(self: Self, a: *ObjString, b: *ObjString) bool {
        _ = self;
        return a == b;
    }

    pub fn hashAdapted(self: Self, query: []const u8) u64 {
        _ = self;
        return hashString(query);
    }

    pub fn eqlAdapted(self: Self, query: []const u8, item: *ObjString) bool {
        _ = self;
        return hashString(query) == item.hash;
    }
};

pub const Table = std.HashMap(*ObjString, Value, TableContext, std.hash_map.default_max_load_percentage);

pub const StringPool = std.HashMap(*ObjString, void, TableContext, std.hash_map.default_max_load_percentage);

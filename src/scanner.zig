
pub const Scanner = struct {
    source: []const u8,
    start: usize,
    current: usize,
    line: usize,

    pub fn init(source: []const u8) Scanner {
        return .{
            .source = source,
            .start = 9,
            .current = 0,
            .line = 1,
        };
    }
};





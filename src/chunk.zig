const std = @import("std");
const Allocator = std.mem.Allocator;

pub const CodeContent = u8;
pub const Value = f64;

pub const OpCode = enum(u8) {
    opreturn,
    constant,

    pub fn size(self: OpCode) usize {
        return switch (self) {
            .opreturn => 1,
            .constant => 2,
        };
    }
};

const CodeList = std.ArrayList(CodeContent);
const LineList = std.ArrayList(u32);
const ValueList = std.ArrayList(Value);

pub const Chunk = struct {
    code: CodeList,
    lines: LineList,
    constants: ValueList,

    pub fn init() Chunk {
        return .{
            .code = .empty,
            .lines = .empty,
            .constants = .empty,
        };
    }

    pub fn write(self: *Chunk, allocator: Allocator, byte: CodeContent, line: u32) !void {
        try self.code.append(allocator, byte);
        try self.lines.append(allocator, line);
    }

    pub fn getContent(self: *Chunk, offset: usize) CodeContent {
        return self.code[offset];
    }

    // Adds a constant to the chunk and returns the index where it was inserted.
    pub fn addConstant(self: *Chunk, allocator: Allocator, value: Value) !usize {
        try self.constants.append(allocator, value);
        return self.constants.items.len - 1;
    }

    pub fn deinit(self: *Chunk, allocator: Allocator) void {
        self.code.deinit(allocator);
        self.lines.deinit(allocator);
        self.constants.deinit(allocator);
    }

    pub fn disassemble(self: *const Chunk, name: []const u8) void {
        // Print a header to identify the chunk.
        std.debug.print("== {s} == \n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            // Re-assign the offset depending on how the instruction was
            // processed since different instructions can have different sizes.
            offset = self.disassembleInstruction(offset);
        }
    }

    pub fn disassembleInstruction(self: *const Chunk, offset: usize) usize {
        std.debug.print("{d:0>4} ", .{offset});

        // Print the instruction's line number or a | if the previous
        // instruction had the same line number.
        if (offset > 0 and self.lines.items[offset] == self.lines.items[offset - 1]) {
            std.debug.print("   | ", .{});
        } else {
            std.debug.print("{d:4} ", .{self.lines.items[offset]});
        }

        // NOTE: we assume that `offset` points to a byte that corresponds to
        // an op code.
        const instruction: OpCode = @enumFromInt(self.code.items[offset]);

        switch (instruction) {
            .opreturn => std.debug.print("OP_RETURN\n", .{}),
            .constant => {
                const constIdx: usize = @intCast(self.code.items[offset + 1]);
                std.debug.print("OP_CONSTANT {d:4} '", .{constIdx});

                const value = self.constants.items[constIdx];

                // Print the value.
                std.debug.print("{d}", .{value});

                std.debug.print("'\n", .{});
            },
        }

        return offset + instruction.size();
    }
};

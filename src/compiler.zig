const std = @import("std");
const Scanner = @import("scanner.zig").Scanner;
const chunk_mod = @import("chunk.zig");
const Chunk = chunk_mod.Chunk;
const OpCode = chunk_mod.OpCode;
const CodeContent = chunk_mod.CodeContent;
const token_mod = @import("token.zig");
const Token = token_mod.Token;
const TokenKind = token_mod.TokenKind;

pub const Parser = struct {
    current: Token,
    previous: Token,
    had_error: bool,
    in_panic_mode: bool,

    pub fn init() Parser {
        return .{
            .current = .eof,
            .previous = .eof,
            .had_error = false,
            .in_panic_mode = false,
        };
    }
};

pub const Compiler = struct {
    source: []const u8,
    scanner: Scanner,
    parser: Parser,
    complingChunk: *Chunk,

    allocator: std.mem.Allocator,

    pub fn init(source: []const u8, alloctor: std.mem.Allocator) Compiler {
        return .{
            .source = source,
            .scanner = Scanner.init(source),
            .parser = Parser.init(),
            .complingChunk = undefined,

            .allocator = alloctor,
        };
    }

    pub fn compile(self: *Compiler, chunk: *Chunk) !bool {
        self.complingChunk = chunk;

        self.advance();
        self.consume(.eof, "End of expression.");

        try self.end();        
        return !self.parser.had_error;
    }

    fn advance(self: *Compiler) void {
        self.parser.previous = self.parser.current;

        while (true) {
            self.parser.current = self.scanner.scanToken();
            if (self.parser.current.kind != .error_token) {
                break;
            }
            self.markErrorAtCurrent(self.parser.current.text_ref);
        }
    }

    fn markErrorAtCurrent(self: *Compiler, message: []const u8) void {
        self.markErrorAt(self.parser.current, message);
    }

    fn markError(self: *Compiler, message: []const u8) void {
        self.markErrorAt(self.parser.previous, message);
    }

    fn markErrorAt(self: *Compiler, token: Token, message: []const u8) void {
        if (self.parser.in_panic_mode) {
            return;
        }
        self.parser.in_panic_mode = true;

        std.debug.print("[line {d}] Error", .{token.line});

        if (token.kind == .eof) {
            std.debug.print(" at end", .{});
        }
        else if (token.kind == .error_token) {
            // No print.
        }
        else {
            std.debug.print(" at '{s}'", .{token.text_ref});
        }
        std.debug.print(": {s} \n", .{message});
        self.parser.had_error = true;
    }

    fn currentChunk(self: *Compiler) *Chunk {
        return self.complingChunk;
    }

    fn consume(self: *Compiler, kind: TokenKind, message: []const u8) void {
        if (self.parser.current.kind == kind) {
            self.advance();
            return;
        }
        self.markErrorAtCurrent(message);
    }

    fn expression(self: *Compiler) void {
        _ = self;
    }

    fn emitByte(self: *Compiler, byte: CodeContent) !void {
        try self.currentChunk().write(self.allocator, byte, self.parser.previous.line);
    }

    fn end(self: *Compiler) !void {
        try self.emitReturn();   
    }

    fn emitReturn(self: *Compiler) !void {
        try self.emitByte(@intFromEnum(OpCode.opreturn));
    }
};
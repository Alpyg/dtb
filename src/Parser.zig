const std = @import("std");
const fdt = @import("fdt.zig");

const Parser = @This();

dtb: [*]const u8,
header: fdt.Header,

current: []const u8,
strings: []const u8,

pub fn init(blob: [*]const u8) Parser {
    const header: fdt.Header = structBigToNative(fdt.Header, @as(*fdt.Header, @ptrCast(@alignCast(@constCast(blob)))).*);
    std.debug.print("{}\n", .{header});

    return Parser{
        .dtb = blob,
        .header = header,
        .current = blob[header.off_dt_struct..][0..header.size_dt_struct],
        .strings = blob[header.off_dt_strings..][0..header.size_dt_strings],
    };
}

pub const Node = union(enum) {
    begin_node: []const u8,
    end_node: void,
    prop: Prop,
    nop: void,
    end: void,

    pub const Prop = struct {
        name: []const u8,
        value: []const u8,

        pub fn format(
            self: *const Prop,
            writer: anytype,
        ) !void {
            try writer.print("{s}: {x}", .{ self.name, self.value });
        }
    };

    pub fn format(
        self: *const Node,
        writer: anytype,
    ) !void {
        switch (self.*) {
            .begin_node => |name| try writer.print("BeginNode({s})", .{name}),
            .end_node => try writer.print("EndNode", .{}),
            .prop => |p| try writer.print("{f}", .{p}),
            .nop => try writer.print("NOP", .{}),
            .end => try writer.print("End", .{}),
        }
    }
};

pub fn next(self: *Parser) !?Node {
    if (self.current.len < 4) return null;

    self.align4();
    const t = self.token();

    return switch (t) {
        .begin_node => {
            const name = self.string();
            return Node{ .begin_node = name };
        },
        .end_node => return Node.end_node,
        .prop => {
            const p = try self.prop();
            return Node{ .prop = p };
        },
        .nop => return Node.nop,
        .end => return Node.end,
        else => |t_| {
            std.debug.print("Unknown token: {}\n", .{t_});
            return self.next();
        },
    };
}

inline fn token(self: *Parser) fdt.Token {
    defer self.current = self.current[4..];
    return @enumFromInt(std.mem.readInt(u32, self.current[0..@sizeOf(u32)], .big));
}

inline fn string(self: *Parser) []const u8 {
    const str: []const u8 = std.mem.sliceTo(self.current, 0);
    defer self.current = self.current[str.len..];
    self.align4();

    return str;
}

inline fn prop(self: *Parser) !Node.Prop {
    const len = self.int(u32);
    const nameoff = self.int(u32);

    if (self.current.len < len) return error.UnexpectedEOF;
    const value = self.current[0..len];
    self.current = self.current[len..];
    self.align4();

    if (nameoff >= self.strings.len) return error.BadStringOffset;
    const name: []const u8 = std.mem.sliceTo(self.strings[nameoff..], 0);
    return .{ .name = name, .value = value };
}

inline fn int(self: *Parser, comptime T: type) T {
    defer self.current = self.current[@sizeOf(T)..];
    return std.mem.readInt(T, self.current[0..@sizeOf(T)], .big);
}

inline fn align4(self: *Parser) void {
    const misalign: usize = @intCast(@intFromPtr(self.current.ptr) & 3);
    if (misalign != 0) {
        const skip = 4 - misalign;
        self.current = self.current[skip..];
    }
}

pub fn structBigToNative(comptime T: type, s: T) T {
    var out = s;
    inline for (@typeInfo(T).@"struct".fields) |field| {
        @field(out, field.name) = std.mem.bigToNative(field.type, @field(s, field.name));
    }
    return out;
}

test "fdt header" {
    const expect = std.testing.expect;
    const allocator = std.testing.allocator;

    const dtb_embed = @embedFile("qemu_riscv.dtb");
    const dtb_blob = try allocator.alignedAlloc(u8, std.mem.Alignment.@"16", dtb_embed.len);
    defer allocator.free(dtb_blob);

    @memcpy(dtb_blob, dtb_embed);

    var parser = init(dtb_blob.ptr);
    while (true) {
        if (try parser.next()) |t| {
            std.debug.print("{f}\n", .{t});
        } else {
            break;
        }
    }

    try expect(parser.header.magic == fdt.Magic);
}

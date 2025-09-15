const std = @import("std");

const fdt = @import("fdt.zig");
pub const FDTMagic = fdt.Magic;
pub const FDTHeader = fdt.Header;
pub const Parser = @import("Parser.zig");

test {
    std.testing.refAllDecls(@This());
}

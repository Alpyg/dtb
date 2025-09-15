const std = @import("std");

pub const Magic: u32 = 0xd00dfeed;

pub const Header = packed struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,

    inline fn strings(self: *Header) []const u8 {
        return @as([*]align(4) const u8, @ptrCast(self))[self.off_dt_strings..self.size_dt_strings];
    }
};

pub const ReserveEntry = packed struct {
    address: usize,
    size: usize,

    pub inline fn from(buf: [*]const u8) ReserveEntry {
        return ReserveEntry{
            .address = std.mem.readInt(usize, buf[0..@sizeOf(usize)], .big),
            .len = std.mem.readInt(usize, buf[@sizeOf(usize) .. @sizeOf(usize) * 2], .big),
        };
    }
};

pub const Token = enum(u32) {
    begin_node = 0x01,
    end_node = 0x02,
    prop = 0x03,
    nop = 0x04,
    end = 0x09,
    _,
};

pub const Prop = packed struct {
    len: u32,
    nameoff: u32,

    pub inline fn from(buf: [*]const u8) Prop {
        return Prop{
            .len = std.mem.readInt(u32, buf[0..@sizeOf(u32)], .big),
            .nameoff = std.mem.readInt(u32, buf[@sizeOf(u32) .. @sizeOf(u32) * 2], .big),
        };
    }
};

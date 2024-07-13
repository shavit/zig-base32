const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Error = error{
    InvalidCharacter,
    InvalidPadding,
    NoSpaceLeft,
    OutOfMemory,
};

pub const chars_rfc4648 = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".*;
//pub const chars_crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ".*;
//pub const chars_hex = "0123456789ABCDEFGHIJKLMNOPQRSTUV".*;
//pub const chars_zbase32 = "ybndrfg8ejkmcpqxot1uwisza345h769".*;

pub const Base32Encoder = struct {
    const Self = @This();
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    pub fn encode(self: *Self, text: []const u8) Error![]u8 {
        const wsize = 5;
        const rem: u8 = @intCast(text.len % wsize);
        const n: u8 = @intCast(text.len / wsize);
        var buf: [9]u8 = .{0} ** 9;
        var list = std.ArrayList(u8).init(self.allocator);

        for (0..n) |i| {
            for (wsize * i..wsize * (i + 1)) |j| {
                buf[buf[8]] = text[j];
                buf[8] += 1;
            }
            const spit = try spit_encoded(buf);
            try list.appendSlice(&spit);
            buf = .{0} ** 9;
        }

        buf[8] = rem;
        if (rem > 0) {
            for (0..rem) |i| {
                buf[i] = text[wsize * n + i];
            }
            const spit = try spit_encoded(buf);
            try list.appendSlice(&spit);
        }

        return list.items;
    }

    fn spit_encoded(src: [9]u8) Error![8]u8 {
        const b32 = Base32Encoder;
        var dest: [8]u8 = .{0} ** 8;
        for (src[8]..8) |i| dest[i] = "="[0];

        if (src[8] > 4) {
            dest[7] = try b32.lookup_b(src[4] & 0x1f);
        }
        if (src[8] > 3) {
            dest[5] = try b32.lookup_b((src[3] >> 2) & 0x1f);
            dest[6] = try b32.lookup_b((src[4] >> 5) | ((src[3] << 3) & 0x1f));
        }
        if (src[8] > 2) {
            dest[4] = try b32.lookup_b((src[3] >> 7) | ((src[2] << 1) & 0x1f));
        }
        if (src[8] > 1) {
            dest[2] = try b32.lookup_b((src[1] >> 1) & 0x1f);
            dest[3] = try b32.lookup_b(((src[2] >> 4) & 0x1f) | (src[1] << 4) & 0x1f);
        }
        if (src[8] > 0) {
            dest[0] = try b32.lookup_b(src[0] >> 3);
            dest[1] = try b32.lookup_b(((src[1] >> 6) & 0x1f) | ((src[0] << 2) & 0x1f));
        }

        return dest;
    }

    fn lookup_b(b: u8) Error!u8 {
        if (chars_rfc4648.len <= b) {
            return Error.InvalidCharacter;
        } else {
            return chars_rfc4648[b];
        }
    }

    fn lookup_v(b: u8) Error!u8 {
        for (chars_rfc4648, 0..) |x, i| {
            if (b == x) {
                return @intCast(i);
            }
        }

        return Error.InvalidCharacter;
    }

    pub fn decode(self: *Self, text: []const u8) Error![]u8 {
        if (text.len % 8 != 0) return Error.InvalidPadding;
        const wsize = 8;
        const n: u8 = @intCast(text.len / wsize);
        var buf: [9]u8 = .{0} ** 9;
        var list = std.ArrayList(u8).init(self.allocator);

        for (0..n) |i| {
            for (wsize * i..wsize * (i + 1)) |j| {
                if (text[j] == "="[0]) break;
                buf[buf[8]] = text[j];
                buf[8] += 1;
            }

            const spit = try spit_decoded(buf);
            try list.appendSlice(spit[0..spit[8]]);
            buf = .{0} ** 9;
        }

        return list.items;
    }

    fn spit_decoded(src: [9]u8) Error![9]u8 {
        var dest: [9]u8 = .{0} ** 9;
        var lut = [_]u8{0} ** 8;
        inline for (0..8) |i| {
            lut[i] = Base32Encoder.lookup_v(src[i]) catch 0;
        }

        if (src[8] > 1) {
            dest[0] = lut[0] << 3 | lut[1] >> 2;
            dest[8] = 1;
        }
        if (src[8] > 3) {
            dest[1] = lut[1] << 6 | lut[2] << 1 | lut[3] >> 4;
            dest[8] = 2;
        }
        if (src[8] > 4) {
            dest[2] = lut[3] << 4 | lut[4] >> 1;
            dest[8] = 3;
        }
        if (src[8] > 6) {
            dest[3] = lut[4] << 7 | lut[5] << 2 | lut[6] >> 3;
            dest[8] = 4;
        }
        if (src[8] == 8) {
            dest[4] = lut[6] << 5 | lut[7];
            dest[8] = 5;
        }

        return dest;
    }
};

const TestPair = struct {
    arg: []const u8,
    expect: []const u8,
};

test "encode string" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var b32 = Base32Encoder.init(allocator);
    const testCases = [_]TestPair{
        .{ .arg = "H", .expect = "JA======" },
        .{ .arg = "He", .expect = "JBSQ====" },
        .{ .arg = "Hel", .expect = "JBSWY===" },
        .{ .arg = "Hell", .expect = "JBSWY3A=" },
        .{ .arg = "Hello", .expect = "JBSWY3DP" },
        .{ .arg = "Hello!", .expect = "JBSWY3DPEE======" },
        .{ .arg = "123456789", .expect = "GEZDGNBVGY3TQOI=" },
        .{ .arg = "123456789012345", .expect = "GEZDGNBVGY3TQOJQGEZDGNBV" },
    };

    for (testCases) |t| {
        const res = try b32.encode(t.arg);
        try testing.expect(std.mem.eql(u8, res, t.expect));
    }
}

test "decode string" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var b32 = Base32Encoder.init(allocator);
    const testCases = [_]TestPair{
        .{ .arg = "JA======", .expect = "H" },
        .{ .arg = "JBSQ====", .expect = "He" },
        .{ .arg = "JBSWY===", .expect = "Hel" },
        .{ .arg = "JBSWY3A=", .expect = "Hell" },
        .{ .arg = "JBSWY3DP", .expect = "Hello" },
        .{ .arg = "JBSWY3DPEE======", .expect = "Hello!" },
        .{ .arg = "GEZDGNBVGY3TQOI=", .expect = "123456789" },
        .{ .arg = "GEZDGNBVGY3TQOJQGEZDGNBV", .expect = "123456789012345" },
    };

    for (testCases) |t| {
        const res = try b32.decode(t.arg);
        try testing.expect(std.mem.eql(u8, res, t.expect));
    }
}

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const Error = error{
    InvalidCharacter,
    InvalidPadding,
    NoSpaceLeft,
    OutOfMemory,
};

// 2-7: 50-55
// A-Z: 65-90
pub const standard_alphabet_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".*;
pub const standard_alphabet_values = [32]u8{
    0b00_00000, // A
    0b00_00001,
    0b00_00010,
    0b00_00011,
    0b00_00100,
    0b00_00101,
    0b00_00110,
    0b00_00111,
    0b00_01000,
    0b00_01001,
    0b00_01010,
    0b00_01011,
    0b00_01100,
    0b00_01101,
    0b00_01110,
    0b00_01111,
    0b00_10000,
    0b00_10001,
    0b00_10010,
    0b00_10011,
    0b00_10100,
    0b00_10101,
    0b00_10110,
    0b00_10111,
    0b00_11000,
    0b00_11001,
    0b00_11010, // 2
    0b00_11011, // 3
    0b00_11100, // 4
    0b00_11101, // 5
    0b00_11110, // 6
    0b00_11111, // 7
};

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
        const rem: u8 = @intCast(u8, text.len % wsize);
        const n: u8 = @intCast(u8, text.len / wsize);
        var buf: [9]u8 = .{0} ** 9;

        const allocator = self.allocator;
        var list = std.ArrayList(u8).init(allocator);

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
        for (standard_alphabet_values, 0..) |x, i| {
            if (b == x) return standard_alphabet_chars[i];
        }

        return Error.InvalidCharacter;
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

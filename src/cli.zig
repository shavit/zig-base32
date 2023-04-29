const std = @import("std");
const mem = std.mem;
const lib = @import("base32.zig");

pub fn main() !void {
    var args = std.process.args();
    if (args.inner.count <= 1) {
        println(help);
        goodbye("Missing arguments", .{});
    }
    _ = args.next();

    if (args.next()) |a| {
        if (mem.eql(u8, a, "-h")) {
            println(help);
            std.process.exit(0);
        }

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var encoder = lib.Base32Encoder.init(allocator);
        const encoded = try encoder.encode(a);
        try write_stdout(encoded);
    }
}

const help =
    "Usage: zbase32 [text] [options]\n" ++ "Options:\n\n" ++ "\t-h Prints this message\n";

fn println(text: []const u8) void {
    std.debug.print("{s}\n", .{text});
}

fn write_stdout(msg: []const u8) !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const writer = bw.writer();

    try writer.print("{s}\n", .{msg});

    try bw.flush();
}

fn goodbye(comptime format: []const u8, args: anytype) noreturn {
    std.log.err(format, args);
    std.process.exit(1);
}

const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "zig-base32",
        .root_source_file = .{ .path = "src/base32.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lib);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/base32.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_main_tests = b.addRunArtifact(main_tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    const cli = b.addExecutable(.{
        .name = "zbase32",
        .root_source_file = .{ .path = "src/cli.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(cli);
    const cli_cmd = b.addRunArtifact(cli);
    cli_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        cli_cmd.addArgs(args);
    }
    const cli_step = b.step("cli", "Start CLI");
    cli_step.dependOn(&cli_cmd.step);
}

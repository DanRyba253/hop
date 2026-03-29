const std = @import("std");
const Args = @import("../Args.zig");
const Env = @import("../Env.zig");
const Walker = @import("../Walker.zig");
const Allocator = std.mem.Allocator;
const compare_files = @import("../compare_files.zig");

const green = "\x1b[32m";
const yellow = "\x1b[33m";
const red = "\x1b[31m";
const bold = "\x1b[1m";
const reset = "\x1b[0m";

pub fn run(arena: Allocator, args: Args, env: Env) !void {
    var walker: Walker = try .walk(arena, env);
    defer walker.deinit();

    if (!args.simple) {
        try env.stdout.print(bold ++ "STATUS       FILE" ++ reset ++ "\n", .{});
    }
    while (walker.next()) |path| {
        const status, const color, const ok = blk: {
            if (compare_files.compare(env, path)) |ok| {
                if (ok) {
                    if (args.diff) continue;
                    break :blk .{ "in sync      ", green, true };
                } else {
                    break :blk .{ "out of sync  ", yellow, false };
                }
            } else |err| switch (err) {
                error.HomeFileNotFound => break :blk .{ "missing      ", red, false },
                error.FailedToAccessHomeFile => {
                    if (!args.quiet) {
                        std.log.err("failed to access file: {s}/{s}", .{ env.home_path, path });
                    }
                    continue;
                },
                error.FailedToAccessBackupFile => {
                    if (!args.quiet) {
                        std.log.err("failed to access file: {s}/{s}", .{ env.backup_path, path });
                    }
                    continue;
                },
            }
        };
        if (args.diff and ok) continue;
        if (!args.simple) {
            if (!args.no_color) {
                try env.stdout.print("{s}{s}{s}", .{ color, status, reset });
            } else {
                try env.stdout.print("{s}", .{status});
            }
        }
        if (!args.realpath) {
            try env.stdout.print("{s}\n", .{path});
        } else {
            try env.stdout.print("{s}/{s}\n", .{ env.backup_path, path });
        }
    }
    try env.stdout.flush();
}

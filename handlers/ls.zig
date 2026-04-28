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

pub fn run(arena: Allocator, args: Args, env: *Env) !void {
    var walker: Walker = try .walkBackup(arena, env);

    if (!args.simple) {
        try env.stdout.print(bold ++ "STATUS       FILE" ++ reset ++ "\n", .{});
    }

    while (walker.next()) |path| {
        const status, const color, const out_of_sync = blk: {
            if (args.simple and !args.out_of_sync) break :blk .{ undefined, undefined, undefined };
            if (compare_files.compare(env, path)) |ok| {
                if (ok) {
                    if (args.out_of_sync) continue;
                    break :blk .{ "in sync      ", green, false };
                } else {
                    break :blk .{ "out of sync  ", yellow, true };
                }
            } else |err| switch (err) {
                error.HomeFileNotFound => {
                    break :blk .{ "missing      ", red, false };
                },
                error.FailedToAccessHomeFile => {
                    if (!args.quiet) {
                        std.log.err(
                            "failed to access file: {s}/{s}",
                            .{ env.home_path, path },
                        );
                    }
                    continue;
                },
                error.FailedToAccessBackupFile => {
                    if (!args.quiet) {
                        std.log.err(
                            "failed to access file: {s}/{s}",
                            .{ env.backup_path, path },
                        );
                    }
                    continue;
                },
            }
        };
        if (!args.simple) {
            if (!args.no_color) {
                try env.stdout.print("{s}{s}" ++ reset, .{ color, status });
            } else {
                try env.stdout.print("{s}", .{status});
            }
        }
        if (!args.realpath) {
            try env.stdout.print("{s}\n", .{path});
        } else {
            try env.stdout.print("{s}/{s}\n", .{ env.backup_path, path });
        }
        if (args.diff and !args.simple and out_of_sync) {
            var cmd_buf: [std.fs.max_path_bytes * 3 + 8]u8 = undefined;
            var cmd_writer = std.Io.Writer.fixed(&cmd_buf);
            try cmd_writer.print("{s} {s}/{s} {s}/{s}\nexit\n", .{
                env.diff_cmd,
                env.home_path,
                path,
                env.backup_path,
                path,
            });
            const result = try std.process.run(arena, env.io, .{
                .argv = &.{ "sh", "-c", &cmd_buf },
            });
            try env.stdout.writeAll(result.stdout);
            if (result.stderr.len > 0) {
                try env.stdout.flush();
                std.log.err("{s}", .{result.stderr});
            }
        }
    }
    try env.stdout.flush();
}

const std = @import("std");
const Args = @import("../Args.zig");
const Env = @import("../Env.zig");
const compare_files = @import("../compare_files.zig");
const Walker = @import("../Walker.zig");
const Allocator = std.mem.Allocator;

pub fn run(arena: Allocator, args: Args, env: *Env) !void {
    var walker: Walker = try .walk(arena, env);
    defer walker.deinit();

    walk: while (walker.next()) |path| {
        var file_exists: bool = true;
        if (compare_files.compare(env, path)) |ok| {
            if (ok) {
                continue;
            }
        } else |err| switch (err) {
            error.HomeFileNotFound => file_exists = false,
            else => {},
        }
        while (file_exists and !args.force) {
            try env.stdout.print("{s}/{s} already exists. Overwrite? [y/N] ", .{
                env.home_path,
                path,
            });
            try env.stdout.flush();
            var response = try env.stdin.takeByte();
            if (response == '\n') {
                response = 'n';
            } else {
                _ = try env.stdin.takeByte();
            }
            if (response == 'y') {
                break;
            }
            if (response == 'n') {
                continue :walk;
            }
            try env.stdout.print("invalid response: {c}\n", .{response});
        }

        env.backup.copyFile(path, env.home, path, .{}) catch {
            if (!args.quiet) {
                std.log.err("failed to copy {s}/{s} to {s}/{s}", .{
                    env.backup_path,
                    path,
                    env.home_path,
                    path,
                });
            }
            continue;
        };

        if (args.verbose and !args.quiet) {
            try env.stdout.print("installing {s}/{s} to {s}/{s}\n", .{
                env.backup_path,
                path,
                env.home_path,
                path,
            });
        }
    }
    try env.stdout.flush();
}

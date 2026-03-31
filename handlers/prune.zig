const std = @import("std");
const Arg = @import("../Args.zig");
const Env = @import("../Env.zig");
const Walker = @import("../Walker.zig");
const Allocator = std.mem.Allocator;

pub fn run(arena: Allocator, args: Arg, env: *Env) !void {
    var walker: Walker = try .walk(arena, env);
    defer walker.deinit();

    walk: while (walker.next()) |path| {
        if (env.home.statFile(path)) |stat| {
            if (stat.kind == .file) continue;
        } else |err| switch (err) {
            error.FileNotFound => {},
            else => {
                if (!args.quiet) {
                    std.log.err("failed to access file: {s}/{s}", .{ env.home_path, path });
                }
                continue;
            },
        }

        while (!args.force) {
            try env.stdout.print("remove {s}/{s}? [Y/n] ", .{
                env.backup_path,
                path,
            });
            try env.stdout.flush();
            var response = try env.stdin.takeByte();
            if (response == '\n') {
                response = 'y';
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

        env.backup.deleteFile(path) catch {
            if (!args.quiet) {
                std.log.err("failed to delete file: {s}/{s}", .{ env.backup_path, path });
                continue;
            }
        };

        if (args.verbose and !args.quiet) {
            try env.stdout.print("removing {s}/{s}\n", .{
                env.backup_path,
                path,
            });
        }

        var sub_dir_path = path;
        while (true) {
            sub_dir_path = std.fs.path.dirname(sub_dir_path) orelse break;
            env.backup.deleteDir(sub_dir_path) catch break;
        }
    }

    try env.stdout.flush();
}

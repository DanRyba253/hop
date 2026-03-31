const std = @import("std");
const Args = @import("../Args.zig");
const Env = @import("../Env.zig");
const compare_files = @import("../compare_files.zig");
const Allocator = std.mem.Allocator;

pub fn run(arena: Allocator, args: Args, env: *Env) !void {
    _ = arena;
    for (env.paths) |path| {
        const path_dir = std.fs.path.dirname(path) orelse ".";
        env.backup.makePath(path_dir) catch {
            if (!args.quiet) {
                std.log.err("failed to create path: {s}/{s}", .{ env.backup_path, path_dir });
            }
            continue;
        };

        if (compare_files.compare(env, path)) |ok| {
            if (ok) continue;
        } else |_| {}

        env.home.copyFile(path, env.backup, path, .{}) catch {
            if (!args.quiet) {
                std.log.err("failed to copy {s}/{s} to {s}/{s}", .{
                    env.home_path,
                    path,
                    env.backup_path,
                    path,
                });
            }
            continue;
        };

        if (args.verbose and !args.quiet) {
            try env.stdout.print("backing up {s}/{s} to {s}/{s}\n", .{
                env.home_path,
                path,
                env.backup_path,
                path,
            });
        }
    }
    try env.stdout.flush();
}

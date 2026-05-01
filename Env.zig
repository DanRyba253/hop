const std = @import("std");
const Args = @import("Args.zig");

const Allocator = std.mem.Allocator;
const Dir = std.Io.Dir;
const List = std.ArrayList;

const openDirAbsolute = std.Io.Dir.openDirAbsolute;
const resolve = std.fs.path.resolvePosix;
const isAbsolute = std.fs.path.isAbsolute;
const startsWith = std.mem.startsWith;
const currentPath = std.process.currentPath;

home: Dir = undefined,
backup: Dir = undefined,
home_path: []const u8 = undefined,
backup_path: []const u8 = undefined,
paths: [][]const u8 = &.{},
stdin_buf: [1024]u8 = undefined,
stdin_reader: std.Io.File.Reader = undefined,
stdin: *std.Io.Reader = undefined,
stdout_buf: [1024]u8 = undefined,
stdout_writer: std.Io.File.Writer = undefined,
stdout: *std.Io.Writer = undefined,
io: std.Io,

pub fn build(
    env: *@This(),
    envMap: std.process.Environ.Map,
    arena: Allocator,
    args: Args,
    errHandler: fn (args: Args, err: Error) error{StoppedByErrHandler}!void,
) (error{StoppedByErrHandler} || Allocator.Error)!void {
    env.home_path = envMap.get("HOME") orelse {
        try errHandler(args, .home_env_var_not_found);
        @panic("Env.build: errHandler expected to error here");
    };

    env.home = openDirAbsolute(env.io, env.home_path, .{}) catch {
        try errHandler(args, .failed_to_open_home_dir);
        @panic("Env.build: errHandler expected to error here");
    };

    var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const cwd_path_len = currentPath(env.io, &buf) catch |e| {
        std.debug.print("{}\n", .{e});
        try errHandler(args, .failed_to_find_realpath_of_cwd);
        @panic("Env.build: errHandler expected to error here");
    };
    const cwd_path = try arena.dupe(u8, buf[0..cwd_path_len]);

    resolve_backup: {
        if (args.backup_dir) |backup_dir_opt| blk: {
            var backup_path_opt: []const u8 = undefined;
            if (isAbsolute(backup_dir_opt)) {
                backup_path_opt = try resolve(arena, &.{backup_dir_opt});
            } else {
                backup_path_opt = try resolve(arena, &.{
                    cwd_path,
                    backup_dir_opt,
                });
            }
            env.backup = openDirAbsolute(env.io, backup_path_opt, .{ .iterate = true }) catch {
                try errHandler(args, .{ .failed_to_open_backup_dir_option = backup_path_opt });
                break :blk;
            };
            env.backup_path = backup_path_opt;
            break :resolve_backup;
        }

        blk: {
            const backup_dir_env = envMap.get("HOP_BACKUP") orelse break :blk;

            if (!isAbsolute(backup_dir_env)) {
                try errHandler(args, .{ .backup_dir_env_var_is_not_absolute = backup_dir_env });
                break :blk;
            }
            const backup_path_env = try resolve(arena, &.{backup_dir_env});
            env.backup = openDirAbsolute(env.io, backup_path_env, .{ .iterate = true }) catch {
                try errHandler(args, .{ .failed_to_open_backup_dir_env_var = backup_path_env });
                break :blk;
            };
            env.backup_path = backup_path_env;
            break :resolve_backup;
        }

        const backup_path_default = try resolve(arena, &.{
            env.home_path,
            ".hop",
        });
        env.backup = openDirAbsolute(env.io, backup_path_default, .{ .iterate = true }) catch {
            try errHandler(args, .{ .failed_to_open_backup_dir_default = backup_path_default });
            @panic("Env.build: errHandler expected to error here");
        };
        env.backup_path = backup_path_default;
    }

    var files: List([]const u8) = .empty;

    for (args.file_paths) |file| {
        var file_path: []const u8 = undefined;
        if (isAbsolute(file)) {
            file_path = file;
        } else {
            file_path = try resolve(arena, &.{
                cwd_path,
                file,
            });
        }
        if (!startsWithDir(file_path, env.home_path)) {
            try errHandler(args, .{ .file_not_in_home_dir = file_path });
            continue;
        }
        const stat = env.home.statFile(env.io, file_path, .{
            .follow_symlinks = false,
        }) catch {
            try errHandler(args, .{ .failed_to_stat_file = file_path });
            continue;
        };
        if (stat.kind != .file) {
            try errHandler(args, .{ .file_not_a_file = file_path });
            continue;
        }
        try files.append(arena, file_path);
    }

    env.paths = try files.toOwnedSlice(arena);

    env.stdin_reader = std.Io.File.stdin().reader(env.io, &env.stdin_buf);
    env.stdin = &env.stdin_reader.interface;

    env.stdout_writer = std.Io.File.stdout().writer(env.io, &env.stdout_buf);
    env.stdout = &env.stdout_writer.interface;
}

pub fn closeDirs(self: *@This()) void {
    self.home.close(self.io);
    self.backup.close(self.io);
}

pub const Error = union(enum) {
    home_env_var_not_found,
    failed_to_open_home_dir,
    failed_to_find_realpath_of_cwd,
    failed_to_open_backup_dir_option: []const u8,
    backup_dir_env_var_is_not_absolute: []const u8,
    failed_to_open_backup_dir_env_var: []const u8,
    failed_to_open_backup_dir_default: []const u8,
    file_not_in_home_dir: []const u8,
    failed_to_stat_file: []const u8,
    file_not_a_file: []const u8,
};

pub fn printDebug(self: @This()) !void {
    var buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    const home_len = try self.home.realPath(self.io, &buf);
    std.debug.print("home: {s}\n", .{buf[0..home_len]});
    const backup_len = try self.backup.realPath(self.io, &buf);
    std.debug.print("backup: {s}\n", .{buf[0..backup_len]});
    std.debug.print("Paths:\n", .{});
    for (self.paths) |path| {
        std.debug.print("  {s}\n", .{path});
    }
}

pub fn defaultErrorHandler(args: Args, err: Error) error{StoppedByErrHandler}!void {
    switch (err) {
        .home_env_var_not_found => {
            if (!args.quiet) std.log.err("$HOME evironment variable not found", .{});
            std.process.exit(1);
        },
        .failed_to_open_backup_dir_env_var => |dir| {
            if (!args.quiet) std.log.err("failed to open backup dir provided by $HOP_BACKUP: {s}", .{dir});
            std.process.exit(1);
        },
        .failed_to_open_backup_dir_default => |dir| {
            if (!args.quiet) std.log.err("failed to open default backup dir: {s}", .{dir});
            std.process.exit(1);
        },
        .file_not_in_home_dir => |file| {
            if (!args.quiet) std.log.err("skipping file not in $HOME: {s}", .{file});
            return;
        },
        .failed_to_open_home_dir => {
            if (!args.quiet) std.log.err("failed to open $HOME", .{});
            std.process.exit(1);
        },
        .failed_to_find_realpath_of_cwd => {
            if (!args.quiet) std.log.err("failed to find realpath of current directory", .{});
            std.process.exit(1);
        },
        .failed_to_open_backup_dir_option => |dir| {
            if (!args.quiet) std.log.err("failed to open backup dir: {s}", .{dir});
            std.process.exit(1);
        },
        .failed_to_stat_file => |file| {
            if (!args.quiet) std.log.err("failed to access file: {s}", .{file});
            return;
        },
        .file_not_a_file => |file| {
            if (!args.quiet) std.log.err("skipping non-file: {s}", .{file});
            return;
        },
        .backup_dir_env_var_is_not_absolute => |dir| {
            if (!args.quiet) std.log.err("$HOP_BACKUP must be an absolute path: {s}", .{dir});
            std.process.exit(1);
        },
    }
}

pub fn startsWithDir(path: []const u8, dir: []const u8) bool {
    if (!startsWith(u8, path, dir)) return false;
    return path[dir.len] == '/';
}

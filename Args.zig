const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const startsWith = std.mem.startsWith;
const eql = std.mem.eql;

backup_dir: ?[]const u8 = null,
help: bool = false,
quiet: bool = false,
force: bool = false,
realpath: bool = false,
verbose: bool = false,
simple: bool = false,
diff: bool = false,
no_color: bool = false,
file_paths: []const []const u8 = &.{},
command: ?Command = null,

pub fn parse(
    arena: Allocator,
    args: []const [:0]const u8,
    errHandler: fn (err: Error) error{StoppedByErrHandler}!void,
) (error{StoppedByErrHandler} || Allocator.Error)!@This() {
    var expecting_backup_dir = false;
    var got_command = false;
    var end_of_options_seen = false;
    var parsed: @This() = .{};
    var files: List([]const u8) = .empty;

    for (args) |arg| {
        options: {
            if (end_of_options_seen) break :options;

            if (isLongOption(arg)) |option_str| {
                if (expecting_backup_dir) {
                    try errHandler(.no_value_after_backup_dir_option);
                    expecting_backup_dir = false;
                }
                if (isKnownLongOption(option_str)) |option| {
                    switch (option) {
                        .backup_dir => expecting_backup_dir = true,
                        .help => parsed.help = true,
                        .quiet => parsed.quiet = true,
                        .force => parsed.force = true,
                        .realpath => parsed.realpath = true,
                        .verbose => parsed.verbose = true,
                        .simple => parsed.simple = true,
                        .diff => parsed.diff = true,
                        .no_color => parsed.no_color = true,
                        .end_of_options => end_of_options_seen = true,
                    }
                    continue;
                }
                try errHandler(.{ .unknown_long_option = option_str });
                continue;
            }

            if (isFlags(arg)) |flags_str| {
                if (expecting_backup_dir) {
                    try errHandler(.no_value_after_backup_dir_option);
                    expecting_backup_dir = false;
                }
                for (flags_str) |flag_char| {
                    switch (flag_char) {
                        'h' => parsed.help = true,
                        'q' => parsed.quiet = true,
                        'f' => parsed.force = true,
                        'r' => parsed.realpath = true,
                        'v' => parsed.verbose = true,
                        's' => parsed.simple = true,
                        'd' => parsed.diff = true,
                        'n' => parsed.no_color = true,
                        else => try errHandler(.{ .unknown_flag = flag_char }),
                    }
                }
                continue;
            }

            if (expecting_backup_dir) {
                parsed.backup_dir = arg;
                expecting_backup_dir = false;
                continue;
            }

            if (!got_command) {
                if (isKnownCommand(arg)) |command| {
                    parsed.command = command;
                    got_command = true;
                    continue;
                }
                try errHandler(.{ .unknown_command = arg });
            }
        }

        try files.append(arena, arg);
    }

    if (expecting_backup_dir) {
        try errHandler(.no_value_after_backup_dir_option);
    }

    if (args.len == 0) {
        parsed.command = .sync;
        parsed.verbose = true;
    }

    if (parsed.command == null and !parsed.help) {
        try errHandler(.no_command_and_no_help_option);
    }

    parsed.file_paths = try files.toOwnedSlice(arena);
    return parsed;
}

pub const Command = enum { add, install, ls, sync, dir, prune, version };

pub const Error = union(enum) {
    no_value_after_backup_dir_option,
    unknown_long_option: []const u8,
    unknown_flag: u8,
    unknown_command: []const u8,
    no_command_and_no_help_option,
};

pub const KnownLongOption = enum {
    backup_dir,
    help,
    quiet,
    force,
    realpath,
    verbose,
    simple,
    diff,
    no_color,
    end_of_options,
};

fn isLongOption(arg: []const u8) ?[]const u8 {
    if (startsWith(u8, arg, "--")) {
        return arg[2..];
    }
    return null;
}

fn isKnownLongOption(option_str: []const u8) ?KnownLongOption {
    if (eql(u8, option_str, "")) return .end_of_options;
    if (eql(u8, option_str, "backup-dir")) return .backup_dir;
    if (eql(u8, option_str, "help")) return .help;
    if (eql(u8, option_str, "quiet")) return .quiet;
    if (eql(u8, option_str, "force")) return .force;
    if (eql(u8, option_str, "realpath")) return .realpath;
    if (eql(u8, option_str, "verbose")) return .verbose;
    if (eql(u8, option_str, "simple")) return .simple;
    if (eql(u8, option_str, "diff")) return .diff;
    if (eql(u8, option_str, "no-color")) return .no_color;
    return null;
}

fn isFlags(arg: []const u8) ?[]const u8 {
    if (arg.len < 2) return null;
    if (arg[0] == '-' and arg[1] != '-') return arg[1..];
    return null;
}

fn isKnownCommand(arg: []const u8) ?Command {
    if (eql(u8, arg, "add")) return .add;
    if (eql(u8, arg, "install")) return .install;
    if (eql(u8, arg, "ls")) return .ls;
    if (eql(u8, arg, "sync")) return .sync;
    if (eql(u8, arg, "dir")) return .dir;
    if (eql(u8, arg, "prune")) return .prune;
    if (eql(u8, arg, "version")) return .version;
    return null;
}

pub fn printDebug(args: @This()) void {
    std.debug.print(
        \\Args:
        \\  backup_dir: {?s},
        \\  help: {},
        \\  quiet: {},
        \\  force: {},
        \\  realpath: {},
        \\  verbose: {},
        \\  simple: {},
        \\  diff: {},
        \\  no_color: {},
        \\  command: {?}
        \\
    , .{
        args.backup_dir,
        args.help,
        args.quiet,
        args.force,
        args.realpath,
        args.verbose,
        args.simple,
        args.diff,
        args.no_color,
        args.command,
    });

    std.debug.print("  File paths:\n", .{});
    for (args.file_paths) |file_path| {
        std.debug.print("    {s}\n", .{file_path});
    }
}

pub fn defaultErrorHandler(err: Error) error{StoppedByErrHandler}!void {
    switch (err) {
        .no_value_after_backup_dir_option => {
            std.log.err("missing value after --backup-dir", .{});
        },
        .unknown_long_option => |option| {
            std.log.err("unknown option: {s}", .{option});
        },
        .unknown_command => |command| {
            std.log.err("unknown command: {s}", .{command});
        },
        .unknown_flag => |flag| {
            std.log.err("unknown flag: {c}", .{flag});
        },
        .no_command_and_no_help_option => {
            std.log.err("missing command", .{});
        },
    }
    std.process.exit(1);
}

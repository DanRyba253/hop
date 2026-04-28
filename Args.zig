const std = @import("std");
const Allocator = std.mem.Allocator;
const List = std.ArrayList;
const startsWith = std.mem.startsWith;
const eql = std.mem.eql;

backup_dir: ?[]const u8 = null,
diff_cmd: ?[]const u8 = null,
help: bool = false,
quiet: bool = false,
force: bool = false,
realpath: bool = false,
verbose: bool = false,
simple: bool = false,
out_of_sync: bool = false,
diff: bool = false,
no_color: bool = false,
file_paths: []const []const u8 = &.{},
action: ?Action = null,

pub fn parse(
    arena: Allocator,
    args: []const [:0]const u8,
    errHandler: fn (err: Error) error{StoppedByErrHandler}!void,
) (error{StoppedByErrHandler} || Allocator.Error)!@This() {
    var option_waiting_for_value: ?KnownLongOption = null;
    var got_action = false;
    var end_of_options_seen = false;
    var parsed: @This() = .{};
    var files: List([]const u8) = .empty;

    for (args) |arg| {
        options: {
            if (end_of_options_seen) break :options;

            if (isLongOption(arg)) |option_str| {
                if (option_waiting_for_value) |waiting_option| {
                    try errHandler(.{
                        .no_value_after_option = .{
                            .waiting_option = waiting_option,
                            .got = option_str,
                        },
                    });
                    option_waiting_for_value = null;
                }
                if (isKnownLongOption(option_str)) |option| {
                    switch (option) {
                        .backup_dir => option_waiting_for_value = .backup_dir,
                        .diff_cmd => option_waiting_for_value = .diff_cmd,
                        .help => parsed.help = true,
                        .quiet => parsed.quiet = true,
                        .force => parsed.force = true,
                        .realpath => parsed.realpath = true,
                        .verbose => parsed.verbose = true,
                        .simple => parsed.simple = true,
                        .out_of_sync => parsed.out_of_sync = true,
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
                if (option_waiting_for_value) |waiting_option| {
                    try errHandler(.{
                        .no_value_after_option = .{
                            .waiting_option = waiting_option,
                            .got = flags_str,
                        },
                    });
                    option_waiting_for_value = null;
                }
                for (flags_str) |flag_char| {
                    switch (flag_char) {
                        'h' => parsed.help = true,
                        'q' => parsed.quiet = true,
                        'f' => parsed.force = true,
                        'r' => parsed.realpath = true,
                        'v' => parsed.verbose = true,
                        's' => parsed.simple = true,
                        'o' => parsed.out_of_sync = true,
                        'd' => parsed.diff = true,
                        'n' => parsed.no_color = true,
                        else => try errHandler(.{ .unknown_flag = flag_char }),
                    }
                }
                continue;
            }

            if (option_waiting_for_value) |waiting_option| {
                switch (waiting_option) {
                    .backup_dir => parsed.backup_dir = arg,
                    .diff_cmd => parsed.diff_cmd = arg,
                    else => unreachable, // other known options don't wait for a value
                }
                option_waiting_for_value = null;
                continue;
            }

            if (!got_action) {
                if (isKnownAction(arg)) |action| {
                    parsed.action = action;
                    got_action = true;
                    continue;
                }
                try errHandler(.{ .unknown_action = arg });
            }
        }

        try files.append(arena, arg);
    }

    if (option_waiting_for_value) |waiting_option| {
        try errHandler(.{
            .no_value_after_option = .{
                .waiting_option = waiting_option,
                .got = "",
            },
        });
    }

    if (args.len == 0) {
        parsed.action = .sync;
        parsed.verbose = true;
    }

    if (parsed.action == null and !parsed.help) {
        try errHandler(.no_action_and_no_help_option);
    }

    parsed.file_paths = try files.toOwnedSlice(arena);
    return parsed;
}

pub const Action = enum {
    add,
    install,
    ls,
    sync,
    dir,
    prune,
    version,
};

pub const Error = union(enum) {
    no_value_after_option: struct {
        waiting_option: KnownLongOption,
        got: []const u8,
    },
    unknown_long_option: []const u8,
    unknown_flag: u8,
    unknown_action: []const u8,
    no_action_and_no_help_option,
};

pub const KnownLongOption = enum {
    backup_dir,
    diff_cmd,
    help,
    quiet,
    force,
    realpath,
    verbose,
    simple,
    out_of_sync,
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
    if (eql(u8, option_str, "diff-cmd")) return .diff_cmd;
    if (eql(u8, option_str, "help")) return .help;
    if (eql(u8, option_str, "quiet")) return .quiet;
    if (eql(u8, option_str, "force")) return .force;
    if (eql(u8, option_str, "realpath")) return .realpath;
    if (eql(u8, option_str, "verbose")) return .verbose;
    if (eql(u8, option_str, "simple")) return .simple;
    if (eql(u8, option_str, "out-of-sync")) return .out_of_sync;
    if (eql(u8, option_str, "diff")) return .diff;
    if (eql(u8, option_str, "no-color")) return .no_color;
    return null;
}

fn isFlags(arg: []const u8) ?[]const u8 {
    if (arg.len < 2) return null;
    if (arg[0] == '-' and arg[1] != '-') return arg[1..];
    return null;
}

fn isKnownAction(arg: []const u8) ?Action {
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
        \\  diff_cmd: {?s},
        \\  help: {},
        \\  quiet: {},
        \\  force: {},
        \\  realpath: {},
        \\  verbose: {},
        \\  simple: {},
        \\  out_of_sync: {},
        \\  diff: {},
        \\  no_color: {},
        \\  action: {?}
        \\
    , .{
        args.backup_dir,
        args.diff_cmd,
        args.help,
        args.quiet,
        args.force,
        args.realpath,
        args.verbose,
        args.simple,
        args.out_of_sync,
        args.diff,
        args.no_color,
        args.action,
    });

    std.debug.print("  File paths:\n", .{});
    for (args.file_paths) |file_path| {
        std.debug.print("    {s}\n", .{file_path});
    }
}

pub fn defaultErrorHandler(err: Error) error{StoppedByErrHandler}!void {
    switch (err) {
        .no_value_after_option => |err_data| {
            const option_str = switch (err_data.waiting_option) {
                .backup_dir => "--backup-dir",
                .diff_cmd => "--diff-cmd",
                else => unreachable, // other known options don't wait for a value
            };
            const got = if (err_data.got.len > 0) err_data.got else "End of options";
            std.log.err("missing value after '{s}'. Got: '{s}'", .{
                option_str,
                got,
            });
        },
        .unknown_long_option => |option| {
            std.log.err("unknown option: {s}", .{option});
        },
        .unknown_action => |action| {
            std.log.err("unknown action: {s}", .{action});
        },
        .unknown_flag => |flag| {
            std.log.err("unknown flag: {c}", .{flag});
        },
        .no_action_and_no_help_option => {
            std.log.err("missing action", .{});
        },
    }
    std.process.exit(1);
}

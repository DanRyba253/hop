const std = @import("std");
const Args = @import("Args.zig");
const Env = @import("Env.zig");
const builtin = @import("builtin");

const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) !void {
    const gpa = init.arena.allocator();

    const raw_args = try init.minimal.args.toSlice(gpa);
    const args: Args = try .parse(gpa, raw_args[1..], Args.defaultErrorHandler);

    if (builtin.mode == .Debug) args.printDebug();

    if (args.help) {
        var buf: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writer(init.io, &buf);
        _ = try stdout.interface.writeAll(
            \\hop - HOme backuP
            \\
            \\USAGE:
            \\  hop [options] <action> [args]
            \\
            \\OPTIONS:
            \\  --backup-dir <dir>     Use <dir> as the backup directory
            \\                         Default: $HOP_BACKUP or $HOME/.hop
            \\  --diff-cmd <command>   Command to use with the 'diff' option
            \\                         Default: $HOP_DIFF_CMD or 'diff -u'
            \\
            \\  -v, --verbose          Show messages for added, synced, or installed files
            \\  -q, --quiet            Suppress messages and errors (overrides --verbose)
            \\  -f, --force            Suppress confirmation prompts:
            \\                           - When using 'install' (file overwrites)
            \\                           - When using 'prune' (removal)
            \\
            \\  -o, --out-of-sync      With 'ls': skip files that are already in sync
            \\  -d, --diff             With 'ls': print diff information
            \\  -r, --realpath         With 'ls': show full paths (not relative to backup dir)
            \\  -s, --simple           With 'ls': show file paths only (no extra info)
            \\  -n, --no-color         With 'ls': disable colored output
            \\
            \\  --                     All arguments after this are treated as file paths
            \\
            \\  -h, --help             Show this help message
            \\
            \\ACTIONS:
            \\  add [files]            Add files to the backup directory
            \\
            \\  sync [files]           Update backup files:
            \\                           - Without arguments: sync all files except those in 'ignore' dirs or .git
            \\                           - With arguments: sync only the specified files
            \\                             (can use original or backup paths)
            \\
            \\  install [files]        Install backup files into $HOME:
            \\                           - Without arguments: install all files except those in 'ignore' dirs or .git
            \\                           - With arguments: install only the specified files
            \\                             (can use original or backup paths)
            \\
            \\  prune [files]          Remove orphaned backups:
            \\                           - Without arguments: remove backups with no matching file in $HOME
            \\                           - With arguments: remove only the specified backup files
            \\
            \\  ls                     Show information about backup files
            \\
            \\  dir                    Print the backup directory path
            \\
            \\SPECIAL USAGE:
            \\  hop (no arguments)     Equivalent to: hop -v sync
        );
        try stdout.interface.flush();
        return;
    }

    var env: Env = .{ .io = init.io };
    try env.build(init.environ_map.*, gpa, args, Env.defaultErrorHandler);
    defer env.closeDirs();

    if (builtin.mode == .Debug) try env.printDebug();

    switch (args.action.?) {
        .dir => try @import("handlers/dir.zig").run(gpa, args, &env),
        .ls => try @import("handlers/ls.zig").run(gpa, args, &env),
        .add => try @import("handlers/add.zig").run(gpa, args, &env),
        .sync => try @import("handlers/sync.zig").run(gpa, args, &env),
        .install => try @import("handlers/install.zig").run(gpa, args, &env),
        .prune => try @import("handlers/prune.zig").run(gpa, args, &env),
        .version => try @import("handlers/version.zig").run(gpa, args, &env),
    }
}

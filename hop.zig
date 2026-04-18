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
            \\USAGE
            \\  hop [options] <command> [args]
            \\OPTIONS
            \\  --backup-dir <dir>
            \\      Use <dir> as the backup directory
            \\      Default: $HOP_BACKUP or $HOME/.hop
            \\  -v, --verbose
            \\      Emit messages about files added, synced or installed
            \\  -q, --quiet
            \\      Don't emit messages (overrides -v, --verbose)
            \\  -f, --force
            \\      When using 'install', don't prompt for confirmation on file overwrite
            \\      When using 'prune', don't prompt for confirmation
            \\  -d, --diff
            \\      When using 'ls', skip files that are in sync
            \\  -r, --realpath
            \\      When using 'ls', print full paths instead of relative to backup directory
            \\  -s, --simple
            \\      When using 'ls', only print file paths
            \\  -n, --no-color
            \\      When using 'ls', don't color text
            \\  -h, --help
            \\      Print this help message
            \\COMMANDS
            \\  add [files]
            \\      Add files to the backup directory
            \\  sync [files]
            \\      Without files:
            \\          Sync all backup files
            \\          Except for files in 'ignore' directories and .git
            \\      With files:
            \\          Sync only the specified files
            \\          Both actual files and their copies in the backup directory can be specified
            \\  install [files]
            \\      Without files:
            \\          Install all backup files into $HOME
            \\          Except for files in 'ignore' directories and .git
            \\      With files:
            \\          Install only the specified files
            \\          Both actual files and their copies in the backup directory can be specified
            \\  ls
            \\      Print information about the backup files
            \\  dir
            \\      Print the backup directory
            \\  prune [files]
            \\      Without files:
            \\          Remove all backup files that do not correspond to any file in $HOME
            \\          and any directories that become empty as a result
            \\      With files:
            \\          Remove only the backup files that are specified
            \\SPECIAL USAGE
            \\  hop (with no arguments)
            \\      Equivalent to 'hop sync -v'
            \\
        );
        try stdout.interface.flush();
        return;
    }

    var env: Env = .{ .io = init.io };
    try env.build(init.environ_map.*, gpa, args, Env.defaultErrorHandler);
    defer env.closeDirs();

    if (builtin.mode == .Debug) try env.printDebug();

    switch (args.command.?) {
        .dir => try @import("handlers/dir.zig").run(gpa, args, &env),
        .ls => try @import("handlers/ls.zig").run(gpa, args, &env),
        .add => try @import("handlers/add.zig").run(gpa, args, &env),
        .sync => try @import("handlers/sync.zig").run(gpa, args, &env),
        .install => try @import("handlers/install.zig").run(gpa, args, &env),
        .prune => try @import("handlers/prune.zig").run(gpa, args, &env),
        .version => try @import("handlers/version.zig").run(gpa, args, &env),
    }
}

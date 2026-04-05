const std = @import("std");
const Args = @import("Args.zig");
const Env = @import("Env.zig");
const builtin = @import("builtin");

const Arena = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var arena: Arena = .init(std.heap.page_allocator);
    defer arena.deinit();
    const gpa = arena.allocator();

    const raw_args = try std.process.argsAlloc(gpa);
    const args: Args = try .parse(gpa, raw_args[1..], Args.defaultErrorHandler);

    if (builtin.mode == .Debug) args.printDebug();

    if (args.help) {
        _ = try std.fs.File.stdout().write(
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
            \\  sync
            \\      Sync backup files
            \\      Except for files in 'ignore' directories and .git
            \\  install
            \\      Install backup files into $HOME
            \\      Except for files in 'ignore' directories and .git
            \\  ls
            \\      Print information about the backup files
            \\  dir
            \\      Print the backup directory
            \\  prune
            \\      Remove backup files that do not correspond to any file in $HOME
            \\      and any directories that become empty as a result
            \\SPECIAL USAGE
            \\  hop (with no arguments)
            \\      Equivalent to 'hop sync -v'
            \\
        );
        return;
    }

    var env: Env = .{};
    try env.build(gpa, args, Env.defaultErrorHandler);
    defer env.closeDirs();

    if (builtin.mode == .Debug) try env.printDebug(gpa);

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

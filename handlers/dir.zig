const std = @import("std");
const Args = @import("../Args.zig");
const Env = @import("../Env.zig");
const Allocator = std.mem.Allocator;

pub fn run(_: Allocator, _: Args, env: *Env) !void {
    try env.stdout.print("{s}\n", .{env.backup_path});
    try env.stdout.flush();
}

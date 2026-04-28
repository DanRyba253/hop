const std = @import("std");
const Args = @import("../Args.zig");
const Env = @import("../Env.zig");
const Allocator = std.mem.Allocator;

const hop_version = "0.0.9";

pub fn run(_: Allocator, _: Args, env: *Env) !void {
    try env.stdout.print("{s}\n", .{hop_version});
    try env.stdout.flush();
}

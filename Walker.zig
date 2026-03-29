const std = @import("std");
const Allocator = std.mem.Allocator;
const Env = @import("Env.zig");

const idxOf = std.mem.indexOf;
const startsWith = std.mem.startsWith;

walker: std.fs.Dir.Walker,

pub fn next(self: *@This()) ?[]const u8 {
    while (true) {
        const entry = (self.walker.next() catch continue) orelse return null;
        if (entry.kind != .file) continue;
        if (startsWith(u8, entry.path, ".git/")) continue;
        if (startsWith(u8, entry.path, "ignore/")) continue;
        if (idxOf(u8, entry.path, "/ignore/") != null) continue;
        return entry.path;
    }
}

pub fn deinit(self: *@This()) void {
    self.walker.deinit();
}

pub fn walk(arena: Allocator, env: Env) !@This() {
    return .{ .walker = try env.backup.walk(arena) };
}

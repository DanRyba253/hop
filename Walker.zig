const std = @import("std");
const Allocator = std.mem.Allocator;
const Env = @import("Env.zig");

const eql = std.mem.eql;

walker: std.Io.Dir.SelectiveWalker,
io: std.Io,

pub fn next(self: *@This()) ?[]const u8 {
    while (true) {
        const entry = (self.walker.next(self.io) catch continue) orelse return null;
        if (entry.kind == .directory) {
            if (eql(u8, entry.basename, ".git")) continue;
            if (eql(u8, entry.basename, "ignore")) continue;
            self.walker.enter(self.io, entry) catch continue;
            continue;
        }
        if (entry.kind != .file) continue;
        return entry.path;
    }
}

pub fn deinit(self: *@This()) void {
    self.walker.deinit();
}

pub fn walk(arena: Allocator, env: *Env) !@This() {
    return .{
        .walker = try env.backup.walkSelectively(arena),
        .io = env.io,
    };
}

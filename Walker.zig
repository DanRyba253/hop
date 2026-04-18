const std = @import("std");
const Allocator = std.mem.Allocator;
const Env = @import("Env.zig");

const eql = std.mem.eql;

impl: Impl,

pub fn walkBackup(arena: Allocator, env: *Env) !@This() {
    return .{ .impl = .{ .backup = .{
        .walker = try env.backup.walkSelectively(arena),
        .io = env.io,
    } } };
}

pub fn walkPaths(env: *Env) @This() {
    return .{ .impl = .{ .paths = .{
        .env = env,
        .current = 0,
    } } };
}

pub fn next(self: *@This()) ?[]const u8 {
    return switch (self.impl) {
        .backup => self.impl.backup.next(),
        .paths => self.impl.paths.next(),
    };
}

const Impl = union(enum) {
    backup: BackupWalker,
    paths: PathsWalker,
};

const BackupWalker = struct {
    walker: std.Io.Dir.SelectiveWalker,
    io: std.Io,

    pub fn next(self: *BackupWalker) ?[]const u8 {
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
};

const PathsWalker = struct {
    env: *Env,
    current: usize,

    pub fn next(self: *PathsWalker) ?[]const u8 {
        if (self.current >= self.env.paths.len) return null;
        defer self.current += 1;
        const path = blk: {
            const full_path = self.env.paths[self.current];
            if (Env.startsWithDir(full_path, self.env.backup_path))
                break :blk full_path[self.env.backup_path.len + 1 ..];
            break :blk full_path[self.env.home_path.len + 1 ..];
        };
        return path;
    }
};

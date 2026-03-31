const std = @import("std");
const Env = @import("Env.zig");
const builtin = @import("builtin");

pub fn compare(env: *Env, file_path: []const u8) Error!bool {
    const backup_file = env.backup.openFile(file_path, .{}) catch {
        return error.FailedToAccessBackupFile;
    };
    defer backup_file.close();

    const home_file = env.home.openFile(file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.HomeFileNotFound,
        else => return error.FailedToAccessHomeFile,
    };
    defer home_file.close();

    const home_stat = home_file.stat() catch {
        return error.FailedToAccessHomeFile;
    };

    const backup_stat = backup_file.stat() catch {
        return error.FailedToAccessBackupFile;
    };

    if (home_stat.size != backup_stat.size) {
        return false;
    }

    var home_reader_buf: [1024]u8 = undefined;
    var home_reader = home_file.reader(&home_reader_buf);

    var backup_reader_buf: [1024]u8 = undefined;
    var backup_reader = backup_file.reader(&backup_reader_buf);

    const buf_size = 1024;
    var home_buf: [buf_size]u8 = undefined;
    var backup_buf: [buf_size]u8 = undefined;

    while (true) {
        const home_size = home_reader.interface.readSliceShort(&home_buf) catch {
            return error.FailedToAccessHomeFile;
        };
        const backup_size = backup_reader.interface.readSliceShort(&backup_buf) catch {
            return error.FailedToAccessBackupFile;
        };

        if (builtin.mode == .Debug) {
            std.debug.assert(home_size == backup_size);
        }

        if (!std.mem.eql(u8, home_buf[0..home_size], backup_buf[0..backup_size])) {
            return false;
        }

        if (home_size < buf_size) {
            break;
        }
    }

    return true;
}

const Error = error{
    FailedToAccessHomeFile,
    FailedToAccessBackupFile,
    HomeFileNotFound,
};

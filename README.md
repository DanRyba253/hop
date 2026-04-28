# hop
HOme backuP

This tool makes it easier to manage copies of select files from $HOME in a separate directory.
> [!WARNING]
> This tool does not create or manage secure backups on it's own.  
> The intended use case is to turn the backup directory into a git repository and push it to a remote.  
> The only supported platform for now is linux.  
> There can be bugs.

## Usage
```
USAGE:
  hop [options] <action> [args]

OPTIONS:
  --backup-dir <dir>     Use <dir> as the backup directory
                         Default: $HOP_BACKUP or $HOME/.hop
  --diff-cmd <command>   Command to use with the 'diff' action
                         Default: $HOP_DIFF_CMD or 'diff -u'

  -v, --verbose          Show messages for added, synced, or installed files
  -q, --quiet            Suppress messages and errors (overrides --verbose)
  -f, --force            Suppress confirmation prompts:
                           - When using 'install' (file overwrites)
                           - When using 'prune' (removal)

  -o, --out-of-sync      With 'ls': skip files that are already in sync
  -d, --diff             With 'ls': print diff information
  -r, --realpath         With 'ls': show full paths (not relative to backup dir)
  -s, --simple           With 'ls': show file paths only (no extra info)
  -n, --no-color         With 'ls': disable colored output

  --                     All arguments after this are treated as file paths

  -h, --help             Show this help message

ACTIONS:
  add [files]            Add files to the backup directory

  sync [files]           Update backup files:
                           - Without arguments: sync all files except those in 'ignore' dirs or .git
                           - With arguments: sync only the specified files
                             (can use original or backup paths)

  install [files]        Install backup files into $HOME:
                           - Without arguments: install all files except those in 'ignore' dirs or .git
                           - With arguments: install only the specified files
                             (can use original or backup paths)

  prune [files]          Remove orphaned backups:
                           - Without arguments: remove backups with no matching file in $HOME
                           - With arguments: remove only the specified backup files

  ls                     Show information about backup files

  dir                    Print the backup directory path

SPECIAL USAGE:
  hop (no arguments)     Equivalent to: hop -v sync
```

> [!NOTE]
> Hop ignores the `.git` subdirectory in the backup directory.  
> Any files in a `ignore` subdirectory are also ignored.

## Building from source
> [!NOTE]
> Zig version 0.16.0 is required.
```bash
git clone https://github.com/DanRyba253/hop.git
cd  hop
zig build-exe -OReleaseFast hop.zig
```

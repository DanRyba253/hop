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
USAGE
  hop [options] <command> [args]
OPTIONS
  --backup-dir <dir>
      Use <dir> as the backup directory
      Default: $HOP_BACKUP or $HOME/.hop
  -v, --verbose
      Emit messages about files added, synced or installed
  -q, --quiet
      Don't emit messages (overrides -v, --verbose)
  -f, --force
      When using 'install', don't prompt for confirmation on file overwrite
      When using 'prune', don't prompt for confirmation
  -d, --diff
      When using 'ls', skip files that are in sync
  -r, --realpath
      When using 'ls', print full paths instead of relative to backup directory
  -s, --simple
      When using 'ls', only print file paths
  -n, --no-color
      When using 'ls', don't color text
  -h, --help
      Print this help message
COMMANDS
  add [files]
      Add files to the backup directory
  sync [files]
      Without files:
          Sync all backup files
          Except for files in 'ignore' directories and .git
      With files:
          Sync only the specified files
          Both actual files and their copies in the backup directory can be specified
  install [files]
      Without files:
          Install all backup files into $HOME
          Except for files in 'ignore' directories and .git
      With files:
          Install only the specified files
          Both actual files and their copies in the backup directory can be specified
  ls
      Print information about the backup files
  dir
      Print the backup directory
  prune [files]
      Without files:
          Remove all backup files that do not correspond to any file in $HOME
          and any directories that become empty as a result
      With files:
          Remove only the backup files that are specified
SPECIAL USAGE
  hop (with no arguments)
      Equivalent to 'hop sync -v'
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

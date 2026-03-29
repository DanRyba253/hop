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
      Don't emit information (overrides -v, --verbose)
  -f, --force
      When using 'install', don't prompt for confirmation on file overwrite
  -d, --diff
      When using 'ls', skip files that are in sync
  -r, --realpath
      When using 'ls', print full paths instead of relative to backup directory
  -s, --simple
      When using 'ls', just print file names
  -n, --no-color
      When using 'ls', don't color text
  -h, --help
      Print this help message
COMMANDS
  add [files]
      Add files to the backup directory
  sync
      Sync backup files
      Except for files in 'ignore' directories and .git
  install
      Install backup files into $HOME
      Except for files in 'ignore' directories and .git
  ls
      Print information about the backup files
  dir
      Print the backup directory
SPECIAL USAGE
  hop (with no arguments)
      Equivalent to 'hop sync -v'
```

> [!NOTE]
> Hop ignores the `.git` subdirectory in the backup directory.  
> Any files in a `ignore` subdirectory are also ignored.

## Building from source
```bash
git clone https://github.com/DanRyba253/hop.git
cd  hop
zig build-exe -OReleaseFast hop.zig
```

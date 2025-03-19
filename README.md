# Shell Functions to Print Physical File Paths

Print absolute path after resolving symlinks (physical path).

Usage: `physpath <path>`

## Installation

  - Part of the Bash Function Library...

  - Relies on `import_func`, `docsh`, `err_msg`...

## Notes

- The target path may be symbolic link, file or directory. The path may contain
  symlinks or relative references like `.` and `..`.

- Works on GNU/Linux or BSD-like systems, including macOS.

- Unlike GNU `readlink -f` or `realpath`, the full path must exist.

- If the path is a directory, `physpath` internally calls `phys_dirpath`.

- Symlinks in the path are resolved after instances of `..`, using the shell
  default behaviour of `cd -L`. Thus, paths like `a/b/s/../`, in which `s` is a symlink
  to `/tmp/c/`, resolve to `a/b/`, rather than `/tmp/`. Use the `-P` flag to change
  this behaviour, and refer to the `phys_dirpath` docs for details.

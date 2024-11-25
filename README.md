# canonpath

Print absolute path after resolving symlinks (canonical path).

Usage: `canonpath <path>`

Notes:

- The target path may be symbolic link, file or directory. The path may contain
  symlinks or relative references like `.` and `..`.

- Works on GNU/Linux or BSD-like systems, including macOS.

- Unlike GNU `readlink -f` or `realpath`, the full path must exist.

- Symlinks in the path are resolved before instances of `..`, using the shell
  built-in command `cd -P`. Thus, paths like `a/b/s/../`, in which `s` is a symlink
  to `/tmp/c/`, resolve to `/tmp/`. With the default `cd -L` behaviour, the path
  would resolve to `a/b/`.

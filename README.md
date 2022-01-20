# Sh-Utils: Shell Utilities for /bin/sh

This repository contains Linux (and similar) shell script utility libraries. They rely on basic shell facilities and a few core utility programs. Specifically:

- POSIX (IEEE Std 1003.1-2008) Shell Command Langauge Specification as detailed at the [Open Group Shell Command Langauge Specification page](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- the `local` utility
- the `tr` utility
- the `sed` utility

The repository has the following structure:

- *bin* directory contains executable scripts - currently library unit tests.
- *lib* utility 'library'  modules that should be included using the source ( . ) syntax into scripts that wish to use them (note: the source command is *not* part of the POSIX shell command language, use . instead: `. 'path/to/library/module'`).
- *doc* documentation for the library modules.

The library modules are:

- `dict.sh` - a collection of functions that allow working with an associative container abstraction.
- `parseargs.sh` - a collection of functions that use `dict.sh` to support an argument parser with functionality similar to the Python ArgsParse package.
- `sh_test.sh` - a simple unit test framework - created to support unit testing the other libraries.

See the documents in the `doc` directory for further information.

---
Copyright (c) 2022 Ralph. E. McArdell

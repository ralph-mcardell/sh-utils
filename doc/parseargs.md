# *parseargs* : Argument parsing for sh scripts

*parseargs* provides argument parsing, particularly command-line arguments parsing, for POSIX standard shell language (a.k.a. *sh*) scripts modelled after the Python *argparse* module.

## Requirements

In addition to the POSIX Shell Command Langauge (Revision of IEEE Std 1003.1-2008 - as detailed at
[The Open Group Shell Command Language page](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_25) - the following facilities are required:

- the *sh-uilts* *dict.sh* library module and thereby its requirements  
  (*parseargs* also uses `local` and `tr`):
  - `local` to declare variables local to function calls
  - `tr` utility to translate characters
  - `sed` utility to replace strings
- `getconf ARG_MAX` to determine limit to maximum possible number of  
  command-line arguments

## Installation

Ensure that the *parseargs.sh* and the *dict.sh* file in the repository *lib* directory is in a known location and access by specifying the pathname or is on the process PATH. *parseargs.sh* assumes *dict.sh* is in the same directory as *parseargs.sh* or can be found on the PATH.

## To use *parseargs.sh*

In a shell script file that wishes to make use of *parseargs.sh* facilities include it with the source include dot operator either by pathname:

`. /path/to/parseargs.sh`

or just by name if you have put *parseargs.sh* on the process' PATH:

`. parseargs.sh`

[Note: the `source` command is a GNU *bash* specific feature.]

## Using *parseargs.sh* facilities

*parseargs* provides a set of functions and a *parser* type whose instances are  *dict* 'objects' having a specific format.

### Calling conventions

All *parseargs* API functions start with the prefix `parseargs_`. Most API functions are intended to be called using shell *Command Substitution*, for example:

```bash
  local new_parser="$(parseargs_new_argument_parser)"
```

A few are meant to be called for execution in the same process as the calling
script:

```bash
  if parseargs_is_argument_parser "${maybe_parser}"; then
    echo "Have argument parser"
  else
    echo "Do not have argument parser"
  fi
```

If a function operates on a *parser* then it is passed as the first argument *by value*. Some functions return a *parser*, often updating that passed to the function.

Some functions accept attributes. These are passed as pairs of arguments: *attribute-name* *attribute-value*, for example:

```bash
  local new_dict="$(parseargs_new_argument_parser \
                            'prog' 'super-utility' \
                     'description' 'Utility that does super wonder stuff.' \
                   )"
```

---

Copyright © 2022 R. E. McArdell

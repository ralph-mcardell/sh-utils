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

A few are meant to be called for execution in the same process as the calling script:

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
  local new_parser="$(parseargs_new_argument_parser \
                            'prog' 'super-utility' \
                     'description' 'Utility that does super wonder stuff.' \
                   )"
```

### Workflow

The sequence for building and using an argument parser is to:

- first create an argument parser with `parseargs_new_argument_parser`, specifying any parser-wide attributes, which are mostly related to program help output.
- add arguments the parser with `parseargs_add_argument` specifying per-argument attributes. 
- sub-parsers, for use with `sub_command` and `sub_argument` arguments, can be added with `parseargs_add_sub_parser`. 
- when the top level argument parser is complete it can be used to parse  arguments, typically `$@`, with `parseargs_parse_arguments`.
- `parseargs_parse_arguments` returns a *dict* containing the argument values except in the case of: `help` or `version` action optional arguments being given when the requested information is output to *stdout* after which parse call process exits.
- errors detected during any *parseargs* function call causes an error message to be output to *stderr* and the call process to exit.

## Reference

### `parseargs_new_argument_parser`

`parseargs_new_argument_parser` is used to create argument parsers, which are specially formatted *dict*s (which are specially formatted strings).

`parseargs_new_argument_parser` takes 0 or more pairs of arguments that provide *attribute-name* *attribute-value* argument pairs. It is valid to not provide values for any attributes in which case defaults will be used.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| n    | (optional) attribute name, n>=1. |
| n+1  | (optional, must be provided if argument *n* provided) attribute value, n>=1 |

The following attributes are supported:

| Attribute name | Value description |
| ----------------- | ----------- |
| 'prog'    | Name of program as used in help (default: $0 )|
| 'usage'    | String describing program usage (default: deduced from arguments added to parser)|
| 'description'    | Text displayed before argument help (default: '') |
| 'epilogue'    | Text displayed after argument help (default: '') |
| 'argument_default'    | Global default value for arguments (default: '') |
| 'add_help'    | Boolean. Add =h / --help option to parser (default: true) |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *parser* value containing specified attributes and an argument specification for *help* option unless `'add_help'` `'false'` specified. The returned *parser* can be used with the other *parseargs* functions and if passed to `parseargs_is_argument_parser` then `parseargs_is_argument_parser` returns *true*. |  |
| 1 (fail) | empty string | Failed to add help optional argument to new parser: ${reason}  [*See `parseargs_add_argument` description for possible reasons*] |



---

Copyright © 2022 R. E. McArdell

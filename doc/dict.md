# Dict : a dictionary associative container for sh scripts

While GNU *bash* has collection types - both arrays and associative maps - the
simple POSIX standard shell language (a.k.a. *sh*) has none.

The *dict* shell language library module provides an associative map container
type - or dictionary, dict for short.

## Requirements

In addition to the POSIX Shell Command Langauge (Revision of IEEE
Std 1003.1-2008 - as detailed at
[The Open Group Shell Command Language page](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_25)

The following facilities are required:

- `local` to declare varibles local to function calls
- `tr` utility to translate characters
- `sed` to replace strings

## Installation

Ensure that the *dict.sh* file in the repository *lib* directory is in a known
location and access by pathname or is on the process PATH.

## To use *dict.sh*

In a shell script file that wishes to make use of *dict.sh* facilities include
it with the source include dot operator either by pathname:

`. /path/to/dict.sh`

or just by name if you have put *dict.sh* on the process' PATH:

`. dict.sh`

[Note: the `source` command is a GNU *bash* specific feature.]

## Using *dict.sh* facilities

A *dict* 'object' is a specially formatted string. *dict* 'objects' are operated
on by a set of functions.

### Calling conventions

All *dict* API functions start with the prefix `dict_`. Most API functions are
intended to be called using shell *Command Substitution*, for example:

```bash
  local new_dict="$(dict_declare)"
```

A few are meant to be called for execution in the same process as the calling
script:

```bash
  if dict_is_dict "${maybe_dict}"; then
    echo "Have dict"
  else
    echo "Do not have dict"
  fi
```

If a function operates on a *dict* then it is passed as the first argument *by
value*. Many, but not all, functions return a *dict*, often updated from that
passed to the function.

Functions that set entries pass them as pairs of arguments, for example:

```bash
  local new_dict="$(dict_declare 'key1' 'value1' 'key2' 'value2')"
```

### Dict entries: keys and values

Dict entries are string keys and string values. These strings may of
course represent numbers on which arithmetic can be performed.

As mentioned dicts are specially formatted strings and use the ASCII (and
therefore also Unicode) often overlooked (and hopefully infrequently used)
separator control characters: FS, GS, RS and US. Hence entry key and value
strings cannot contain these values.

Dicts can be nested, one dict as an entry value of another.

### Simple dict functions

Some functions have variants suffixed with `_simple`. These functions do *not*
support nesting of *dict* values. Nesting a *dict* as a value of another
requires additional work and values need to be checked to see if they are
a *dict* and require the additional handling. The `_simple` function variants
do not bother to check values, assuming they are *not* *dict*s.

### Dict Hello World

Here is a Hello World example. It shows:

- creating a *dict* and populating it with initial entries with non-*dict*
values.
- accessing the entry values so they can be output to *stdout*.
- updating the values

```bash
#!/bin/sh

# Include the dict code. This assumes dict.sh is either in the same directory
# as the executing script or on the PATH. If not then use the dict.sh path:
. dict.sh

# Declare a dict 'object' string and populate with entries for the greeting
# and who is greeted, the dict 'object' is returned:
record="$(dict_declare_simple 'greeting' 'Hello' 'who' 'World')"

# Lookup the values associated with keys greeting and who and echo them to
# stdout:
echo "$(dict_get_simple "${record}" 'greeting'), $(dict_get_simple  "${record}" 'who')!"

# Set values for keys greeting and who; as these both exist they are updated.
# Note that the record variable is both used as an input argument and
# receives the updated dict:
record="$(dict_set_simple "${record}" 'greeting' 'Hi' 'who' 'Earth')"

# Lookup and echo the updated associated values to stdout. This time
# store the returned values in variables and output their values:
greeting="$(dict_get_simple "${record}" 'greeting')"
who="$(dict_get_simple  "${record}" 'who')"
echo "${greeting}, ${who}!"
```

---
Copyright © 2021 R. E. McArdell

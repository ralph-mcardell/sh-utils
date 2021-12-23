# Dict : a dictionary associative container for sh scripts

While GNU *bash* has collection types - both arrays and associative maps - the
simple POSIX standard shell language (a.k.a. *sh*) has none.

The *dict* shell language library module provides an associative map container
type - or dictionary, dict for short.

## Installation

Ensure that the *dict.sh* file in the repository *lib* directory is in a known
location and access by pathname or is on the process PATH.

## To use *dict.sh*

In a shell script file that wishes to make use of *dict.sh* facilities include
it with the source include dot operator either by pathname:

`. /path/to/dict.sh`

or just by name if you have put *sh_test.sh* on the process' PATH:

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

---
Copyright © 2021 R. E. McArdell

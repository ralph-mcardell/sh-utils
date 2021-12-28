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

## Reference

### Function synopsis

| Function name | Description |
| ------------- | ----------- |
| `dict_declare` `dict_declare_simple`  | declare a *dict* variable, optionally initialised with initial key, value entries. Returns the *dict* value that can be associated with a variable. |
| `dict_set` `dict_set_simple` | add or update one or more key,value pairs to a previously `dict_declare`'d variable. Returns the updated *dict*. |
| `dict_get` `dict_get_simple` | retrieve a value associated with a key in a previously `dict_declare`'d variable. Return the value if passed key present or blank if it is not. |
| `dict_remove` | remove a key,value entry from a *dict*. Returns the updated *dict*.|
| `dict_is_dict` | check if a variable's value represents a *dict* type. |
| `dict_size` `dict_count` | return the integer value of the size of a *dict*, being the number of records. `dict_size is` ~O(1) whereas `dict_count` is ~O(n), hence `dict_size` is intended to be usually used over `dict_count`, which iterates over the entries in a *dict* and returns the count of records iterated over. |
| `dict_for_each` | iterate over the entries of a *dict* calling a function for each key value pair. |
| `dict_print_raw` | print the raw string of a *dict* variable with substitutions for the US, RS, GS and FS non-printing separator characters. Useful for debugging and similar. |
| `dict_pretty_print` | output *dict* entries with customisable surrounding decoration. |
| `dict_op_to_var_flat` | for use with `dict_for_each`. Create variables with the value of *dict* entries' value and a name based on the *dict* entries' key value with optional prefix and/or suffix. |

### `dict_declare` `dict_declare_simple`

`dict_declare` and `dict_declare_simple` are used to create *dict* 'object' strings. If called with no values they return an empty *dict*. If passed pairs of keys and values these are used to populate the new *dict*.

If no entry values are themselves *dict*s then `dict_declare_simple` can be safely called. Key values may not be *dict*s for either `dict_declare_simple` or `dict_declare`. For both `dict_declare` and `dict_declare_simple` neither keys nor values can contain ASCII US, RS, GS or FS characters.

`dict_declare` and `dict_declare_simple` are designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 2n-1 | entry n key value. n > 0. |
| 2n   | entry n value value. n > 0. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *dict* value containing 0+ entries that can be used with the other *dict* functions and if passed to `dict_is_dict` then `dict_is_dict` returns *true*. |  |
| 1 (fail) | empty string | duplicate key "$key" passed to dict_declare{_simple}. |

### `dict_set` `dict_set_simple`

`dict_set` and `dict_set_simple` are used to update existing entries and add
new entries to an existing *dict* 'object'. If the passed *dict* has an
existing entry with a key that matches an entry key to set then the existing
entry is updated otherwise a new entry is appended to the end of the *dict*
'object' string.

If no passed entry values are themselves *dict*s then `dict_set_simple` can
be safely called. Key values may not be *dict*s for either `dict_set_simple` or
`dict_set`. For both `dict_set` and `dict_set_simple` neither keys nor values
can contain ASCII US, RS, GS or FS characters.

`dict_set` and `dict_set_simple` are designed to be called using *Command
Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to set entries in. |
| 2    | entry key value. |
| 3    | entry value value. |
| 4+2n | (optional) additional entry key value. n >= 0. |
| 5+2n | (optional) additional entry value value. n >= 0. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *dict* value containing the updated and/or added entries. |  |
| 1 (fail) | empty string | First argument passed to dict_set{_simple} is not a dict(ionary) type. |

### `dict_get` `dict_get_simple`

`dict_get` and `dict_get_simple` are used to retreive an entry value from an existing *dict* 'object' given the entry's key value.

If the retrived value is not a *dict* then `dict_get_simple` can be safely
called. The key value may not be *dict*s for either `dict_get_simple` or
`dict_get`. For both `dict_get` and `dict_get_simple` neither keys nor values
can contain ASCII US, RS, GS or FS characters.

`dict_get` and `dict_get_simple` are designed to be called using *Command
Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to lookup value in. |
| 2    | entry key whose value to return. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | value for entry with passed key or empty string if no matching entry exists in the passed *dict*. |  |
| 1 (fail) | empty string | First argument passed to dict_get{_simple} is not a dict(ionary) type. |

---

Copyright © 2021 R. E. McArdell

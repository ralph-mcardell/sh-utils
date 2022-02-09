# *dict* : a dictionary associative container for sh scripts

While GNU *bash* has collection types - both arrays and associative maps - the simple POSIX standard shell language (a.k.a. *sh*) has none.

The *dict* shell language library module provides an unordered associative map container type - or dictionary, dict for short.

## Requirements

In addition to the POSIX Shell Command Langauge (Revision of IEEE Std 1003.1-2008 - as detailed at [The Open Group Shell Command Language page](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_25) - the following facilities are required:

- `local` to declare variables local to function calls
- `tr` utility to translate characters
- `sed` utility to replace strings

## Installation

Ensure that the *dict.sh* file in the repository *lib* directory is in a known location and access by specifying the pathname or is on the process PATH.

## To use *dict.sh*

In a shell script file that wishes to make use of *dict.sh* facilities include it with the source include dot operator either by pathname:

`. /path/to/dict.sh`

or just by name if you have put *dict.sh* on the process' PATH:

`. dict.sh`

[Note: the `source` command is a GNU *bash* specific feature.]

## Using *dict.sh* facilities

A *dict* 'object' is a specially formatted string. *dict* 'objects' are operated on by a set of functions.

### Calling conventions

All *dict* API functions start with the prefix `dict_`. Most API functions are intended to be called using shell *Command Substitution*, for example:

```bash
  local new_dict="$(dict_declare)"
```

A few are meant to be called for execution in the same process as the calling script:

```bash
  if dict_is_dict "${maybe_dict}"; then
    echo "Have dict"
  else
    echo "Do not have dict"
  fi
```

If a function operates on a *dict* then it is passed as the first argument *by value*. Many, but not all, functions return a *dict*, often updated from that passed to the function.

Functions that set entries pass them as pairs of arguments, for example:

```bash
  local new_dict="$(dict_declare 'key1' 'value1' 'key2' 'value2')"
```

### Dict entries: keys and values

Dict entries are string keys and string values. These strings may of course represent numbers on which arithmetic can be performed.

As mentioned *dicts* are specially formatted strings and use the ASCII (and therefore also Unicode) often overlooked (and hopefully infrequently used) separator control characters: FS, GS, RS and US. Hence entry key and value strings cannot contain these values.

*Dicts* can be nested, one *dict* as an entry value of another, however this requires extra processing to ensure the special seperator characters in nested *dict* values are modified on insertion and restored on extraction.

*Dict* keys cannot be *dict*s.

### Simple dict functions

Some functions have variants suffixed with `_simple`. These functions do *not* support nesting of *dict* values. As mention above nesting a *dict* as a value of another requires additional work and values need to be checked to see if they are a *dict* and require the additional handling. The `_simple` function variants do not bother to check values, assuming they are *not* *dict*s.

### Dict Hello World

Below is shown a *Hello World* example. It shows:

- creating a *dict* and populating it with initial entries with non-*dict* values.
- accessing the entry values so they can be output to *stdout*.
- updating the values.

As only simple string values are being stored - no nested *dict*s - the `_simple` versions of *dict* functions are used.

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
printf '%s\n' "$(dict_get_simple "${record}" 'greeting'), $(dict_get_simple  "${record}" 'who')!"

# Set values for keys greeting and who; as these both exist they are updated.
# Note that the record variable is both used as an input argument and
# receives the updated dict:
record="$(dict_set_simple "${record}" 'greeting' 'Hi' 'who' 'Earth')"

# Lookup and echo the updated associated values to stdout. This time
# store the returned values in variables and output their values:
greeting="$(dict_get_simple "${record}" 'greeting')"
who="$(dict_get_simple  "${record}" 'who')"
printf '%s\n' "${greeting}, ${who}!"
```

## Reference

### Function synopsis

| Function name | Description |
| ------------- | ----------- |
| `dict_declare` `dict_declare_simple`  | declare a *dict* variable, optionally initialised with initial key, value entries. Returns the *dict* value that can be associated with a variable. |
| `dict_set` `dict_set_simple` | add or update one or more key,value pairs to a previously `dict_declare`'d variable. Returns the updated *dict*. |
| `dict_get` `dict_get_simple` | retrieve a value associated with a key in a previously `dict_declare`'d variable. Return the value if passed key present or blank if it is not. |
| `dict_remove` | remove key,value entries from a *dict*. Returns the updated *dict*.|
| `dict_is_dict` | check if a variable's value represents a *dict* type. |
| `dict_size` `dict_count` | return the integer value of the size of a *dict*, being the number of records. `dict_size` is ~O(1) whereas `dict_count` is ~O(n), hence `dict_size` is intended to be usually used over `dict_count`, which iterates over the entries in a *dict* and returns the count of records iterated over. |
| `dict_for_each` | iterate over the entries of a *dict* calling a function for each key,value pair. |
| `dict_pretty_print` | output *dict* entries with customisable surrounding decoration. |
| `dict_print_raw` | print the raw string of a *dict* variable with substitutions for the US, RS, GS and FS non-printing separator characters. Useful for debugging and similar. |
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

`dict_set` and `dict_set_simple` are used to update existing entries and add new entries to an existing *dict* 'object'. If the passed *dict* has an existing entry with a key that matches an entry key to set then the existing entry is updated otherwise a new entry is appended to the end of the *dict* 'object' string.

If no passed entry values are themselves *dict*s then `dict_set_simple` can be safely called. Key values may not be *dict*s for either `dict_set_simple` or `dict_set`. For both `dict_set` and `dict_set_simple` neither keys nor values can contain ASCII US, RS, GS or FS characters.

`dict_set` and `dict_set_simple` are designed to be called using *Command Substitution*.

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

If the retrived value is not a *dict* then `dict_get_simple` can be safely called. The key value may not be *dict*s for either `dict_get_simple` or `dict_get`. For both `dict_get` and `dict_get_simple` neither keys nor values can contain ASCII US, RS, GS or FS characters.

`dict_get` and `dict_get_simple` are designed to be called using *Command Substitution*.

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

### `dict_remove`

`dict_remove` is used to remove entries from an existing *dict* 'object' given entry key values.

The passed key values may not be a *dict* nor contain ASCII US, RS, GS or FS characters.

`dict_remove` is designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to remove entries from. |
| 2+   | keys of entries which are to be removed. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *dict* value matching that passed for the first parameter with the entries matching the passed key values removed which will be an exact copy of the passed in *dict* if no matching entries exist in the passed *dict*. |  |
| 1 (fail) | empty string | First argument passed to dict_remove is not a dict(ionary) type. |

### `dict_is_dict`

`dict_is_dict` checks the single passed parameter is a *dict*. That is it checks the passed value appears to be in the correct format to be a *dict*.

`dict_is_dict` is intended to be called directly and *not* via *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | Value to check whether it is a *dict* or not |

#### Return values

*true* if the passed value appears to be a *dict*.

*false* if the passed value does not appear to be a *dict*

### `dict_size` `dict_count`

`dict_size` and `dict_count` return the number of entries in a *dict*.

`dict_size` returns an entry count value maintained in the *dict* and thus in theory executes in ~O(1) (i.e. constant) time - although it might be some factor of **n**, the number of entries, due to having to operate on a string. It should be preferred to *dict_count* in most situations.

`dict_count` iterates over the entries in a *dict* to determine the number of entries it contains. `dict_count` therefore executes at best in ~O(n) (linear time). Its main intended use is for testing and debugging.

`dict_size` and `dict_count` are designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to obtain number of entries for. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | 0 or positive integer value of the number of entries in the passed *dict*. |  |
| 1 (fail) | empty string | First argument passed to dict_{size \| count} is not a dict(ionary) type. |

### `dict_for_each`

`dict_for_each` iterates over the entries of a *dict*, calling a specified function for each entry. The called function is passed:

- the entry key
- the entry value
- the number of the entry, indexed from 0
- any extra parameters passed to `dict_for_each`

`dict_count` and `dict_pretty_print` are implemented in terms of `dict_for_each`.

`dict_for_each` is intended to be called directly and *not* via *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to iterate over the entries of. |
| 2    | name of function to call for each entry. |
| 3+   | (optional) additional arguments to pass to each function invocation |

#### Return values

Nothing if the call to `dict_for_each` succeeded.

Will exit the call execution process with a return value of 1 and a 'First argument passed to dict_for_each is not a dict(ionary) type.' message on *stderr* if the first argument passed is not a *dict*. Note that it is likely that `dict_for_each` will be directly called in the context of the calling script in which case the error will exit the calling script.

Similar considerations apply to any errors raised by the function called by `dict_for_each`.

### `dict_pretty_print`

`dict_pretty_print` outputs to *stdout* the keys and values in a *dict* using caller-specified format decoration around data elements of the passed *dict*, recursively applying the formatting specificaiton to nested *dict* values.

The formatting decoration is specified as a *dict* passed as the second parameter that has specific entries. Any entry not provided in the specification *dict* is output as an empty string. Hence providing an empty specification *dict* will just output each key,value in order,
including nested *dict* values, with no separation between each key and value or between each key, value entry.

The available specification keys and the use of their associated values are:

| Specification key | Value's use |
| ----------------- | ----------- |
| 'print_prefix'    | Characters output before any other dict output |
| 'print_suffix'    | Characters output after all other dict output |
| 'nesting_indent'  | Characters output after any newlines for nested dict output; applied to existing indent on each subsequent string. |
| 'nesting_prefix'  | Characters output before any other nested dict output |
| 'nesting_suffix'  | Characters output after all other nested dict output |
| 'dict_prefix'     | Characters output before any dict entry output |
| 'dict_suffix'     | Characters output after all dict entry output |
| 'record_separator'| Characters output between 'record_prefix' and 'record_suffix' characters. Useful for producing list separators without trailing separator. |
| 'record_prefix'   | Characters output before each dict entry output |
| 'record_suffix'   | Characters output after each dict entry output |
| 'key_prefix'      | Characters output before each dict entry key output |
| 'key_suffix'      | Characters output after each dict entry key output |
| 'value_prefix'    | Characters output before each dict entry value output |
| 'value_suffix'    | Characters output after each dict entry value output |

As implied in the description of the value for the 'nesting_indent' key print specification string values may contain newlines.

`dict_pretty_print` may be called directly to send to output to stdout, or via *Command Substitution* to capture the output.
#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to pretty print. |
| 2    | *dict* value providing the formatting specification. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | pretty printed representation of the *dict* passed as parameter 1. |  |
| 1 (fail) | empty string | First argument passed to dict_pretty_print is not a dict(ionary) type. |
| 1 (fail) | empty string | Print specifications argument #2 passed to dict_pretty_print is not a dict(ionary) type. |

### `dict_print_raw`

`dict_print_raw` outputs raw *dict* strings to *stdout* after translating the unprintable ASCII US RS GS and FS characters with the *tr* utility.

The characters the unprintable characters are translated to are specified by the optional second parameter in the order US RS GS FS (no spaces), which if
not given defaults to:

- US : _ (underscore / low line)
- RS : ^ (caret / circumflex accent)
- GS : ] (right square bracket)
- FS : \ (backslash)

i.e. the string `'_^]\'` is passed to *tr* as the characters to translate to.

`dict_print_raw` is primarily intended as a debug aid to check the format of *dict* strings. It may be called directly so as to see the output on the console or via *Command Substitution* to capture the output.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | *dict* value to translate the unprintable characters and output. |
| 2    |  (optional) string of 4 characters to translate the US RS GS FS unprintable format characters to (no spaces, in that order). Defaults to '_^]\\'. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | contents of first parameter after translating the unprintable characters US RS GS FS using the contents of the second (possibly defaulted) parameter using the *tr* utility. |
|?? (fail) | empty string | none unless *tr* or *echo* produce an error. Specifically note that the first parameter is *not* checked that it is a *dict* type. |

### `dict_op_to_var_flat`

`dict_op_to_var_flat` is an operation function intended to be passed to `dict_for_each`.

`dict_op_to_var_flat` will create a variable having the value of the value passed as the second parameter and a name based on the key-value passed as the first parameter.

The name of the created variable in the simplest case is simply the same as the key value. Optional prefix and suffix forth and fifth parameters may be passed in which case the name will be of the form:

  `${prefix}${key}${suffix}`

that is:

  `${4}${1}${5}`

If the formed string is not a valid variable identifer bad things will happen. To provide a suffix without a prefix specify the prefix as a hyphen.

If the value represents a nested *dict* then the value is unnested.

Usage examples:

1. **simple**: create variables matching key names of entries in *dict*:  
   `dict_for_each "${dict}" dict_op_to_var_flat`

2. **with prefix**: create variables of the form *dict_keyname*:  
   `dict_for_each "${dict}" dict_op_to_var_flat 'dict_'`

3. **with suffix**: create variables of the form *keyname_dict*:  
   `dict_for_each "${dict}" dict_op_to_var_flat '-' '_dict'`

4. **with prefix and suffix**: create variables of the form *dict_keyname_0*:  
   `dict_for_each "${dict}" dict_op_to_var_flat 'dict_' '_0'`

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1 | key value (passed by `dict_for_each`) |
| 2 | value value (passed by `dict_for_each`) |
| 3 | record index (passed by `dict_for_each` - ignored)
| 4 | (optional) variable name prefix or '-' for suffix only |
| 5 | (optional) variable name suffix |

#### Return values

None; $? is 0 unless the *read* utility rasies an error, e.g. the constructed variable name is invalid.

## Example uses

### Nesting dicts

It is very common to find cases where a value associated with a key is itself composed of multiple values. This example extends the *Hello World* example shown previously by having the greeting *dict* also include the foreground and background colours to be used to display the greeting as RGB triples.

The example demonstrates:

- using the non-simple versions of *dict* API functions when any entry
  value is or maybe a nested *dict*.
- passing *dict* values as function arguments.
  
```bash
#!/bin/sh

# Include the dict code. This assumes dict.sh is either in the same directory
# as the executing script or on the PATH. If not then use the dict.sh path:
. dict.sh

# Define ANSI terminal control sequence constants.
# Assume we have tr available but only a basic echo that supports
# neither -e nor \e:
readonly ASCII_ESC=$(echo '@' | tr '@' '\033')
readonly ANSI_CMD_PREFIX="${ASCII_ESC}["
readonly ANSI_CMD_END="2m"
readonly ANSI_CMD_RESET="${ANSI_CMD_PREFIX}0m"
readonly ANSI_CMD_FG_MULTIBIT="${ANSI_CMD_PREFIX}38"
readonly ANSI_CMD_BG_MULTIBIT="${ANSI_CMD_PREFIX}48"
readonly ANSI_CMD_FG_24BIT="${ANSI_CMD_FG_MULTIBIT};2"
readonly ANSI_CMD_BG_24BIT="${ANSI_CMD_BG_MULTIBIT};2"

# Build the ANSI terminal command string to set foreground and background
# colours using 24 bit RGB triples. The fore- and back-ground RGB values
# are passed as parameters 1 and 2 respectfully in dicts with entries r, g
# and b with integer values between 0 and 255. The resultant string is
# returned in the return_value variable.
set_ansi_24bit_colours_string() {
  local fg="${1}"
  local bg="${2}"
  local r="$(dict_get_simple "${fg}" 'r')"
  local g="$(dict_get_simple "${fg}" 'g')"
  local b="$(dict_get_simple "${fg}" 'b')"
  local fg_cmd="${ANSI_CMD_FG_24BIT};${r};${g};${b}${ANSI_CMD_END}"

  r="$(dict_get_simple "${bg}" 'r')"
  g="$(dict_get_simple "${bg}" 'g')"
  b="$(dict_get_simple "${bg}" 'b')"
  return_value="${fg_cmd}${ANSI_CMD_BG_24BIT};${r};${g};${b}${ANSI_CMD_END}"                                     
}

# Declare a dict 'object' string and populate with entries for the foreground
# and background colours to display the greeting in addition to the greeting
# and who is greeted. Note that we have to use dict_declare rather than
# dict_declare_simple when initialising with nested dict values:
record="$(dict_declare 'greeting' 'Hello' 'who' 'World' \
                       'foreground' "$(dict_declare_simple 'r' '127' \
                                                           'g' '255' \
                                                           'b' '80' \
                                    )" \
                       'background' "$(dict_declare_simple 'r' '80' \
                                                           'g' '0' \
                                                           'b' '0' \
                                    )" \
        )"

# Lookup foreground and background RGB triples and pass to 
# set_ansi_24bit_colours_string. As these values are nested dicts dict_get
# must be used:
set_ansi_24bit_colours_string "$(dict_get "${record}" 'foreground')" \
                              "$(dict_get "${record}" 'background')"

# Lookup the values associated with keys greeting and who and echo them to
# stdout along with the ANSI colour setting string. As the looked up values
# are simple strings dict_get_simple can be used:
printf '%s' "${return_value}"
printf '%s' "$(dict_get_simple "${record}" 'greeting'), $(dict_get_simple  "${record}" 'who')!"
printf '%s\n' "${ANSI_CMD_RESET}"

# Set values for keys greeting and who; as these both exist they are updated.
# Note that the record variable is both used as an input argument and
# receives the updated dict:
record="$(dict_set_simple "${record}" 'greeting' 'Hi' 'who' 'Earth')"

# Similarly the RGB colours can be set, however as these are stored as
# nested dicts dict_set must be used. Note that we could combine the
# previous call to dict_set_simple with the following call to dict_set
# and set new values for all entries in one go:
record="$(dict_set "${record}" 'foreground' "$(dict_declare_simple 'r' '255' \
                                                                   'g' '127' \
                                                                   'b' '80' \
                                    )" \
                               'background' "$(dict_declare_simple 'r' '0' \
                                                                   'g' '80' \
                                                                   'b' '0' \
                                    )" \
        )"

# Once again pass the colour dict values to set_ansi_24bit_colours_string
# but this time store in variables first:
fore="$(dict_get "${record}" 'foreground')"
back="$(dict_get "${record}" 'background')"
set_ansi_24bit_colours_string "${fore}" "${back}"

# Lookup and output the updated associated values to stdout along with
# the ANSI colour setting string. This time store the returned values
# in variables and output their values:
greeting="$(dict_get_simple "${record}" 'greeting')"
who="$(dict_get_simple  "${record}" 'who')"
printf '%s\n' "${return_value}${greeting}, ${who}!${ANSI_CMD_RESET}"
```

### Simulating a set

A set is an unordered collection of values. It is similar to a dictionary
that only has keys (rather than key:value pairs) as entries. *dict*
objects can simulate a set by storing set members as key:value pairs with
any non-empty string *don't care* value, a single underscore - '_' - for
example.

This example uses *dict* objects in such a simulated set manner with some
sample common set operation implementations. This example demonstrates:

- using *dict* objects to simulate sets.
- more uses of `dict_declare_simple`, `dict_get_simple` and `dict_set_simple`.
- use of `dict_for_each` with *dict* iteration functions.
- using `dict_pretty_print` with a print specification *dict*.

```bash
#!/bin/sh

# Include the dict code. This assumes dict.sh is either in the same directory
# as the executing script or on the PATH. If not then use the dict.sh path:
. dict.sh

# Define functions to work with dicts simulating sets. Most functions return
# their value in the gobal set_return_value variable, which we initialse to a
# known, empty, state here:
set_return_value=''

# Define a set_declare function that wraps a call to dict_declare_simple.
# Like dict_declare/dict_declare_simple set_declare take an optional,
# variable, number of values to initialise the new set-dict with, however
# each argument is a *whole* set entry which must be paired with a
# non-empty but otherwise don't care value before being passed to
# dict_declare_simple:
set_declare() {
  # Insert a '_' value after each passed set value to convert them to
  # dict key:value entry argument pairs. This has to be done carefully as
  # we are consuming and modifying $@ at the same time! The method is:
  #   1. set the count of how many parameter values $@ contains _before_
  #      we start. This is because the number of parameters varies as
  #      each '_' is added.
  #   2. iterate for each parameter originally in $@ - i.e. count times:
  #     2.1. grab the next set value, which is the next dict key.
  #     2.2. remove this value from $@
  #     2.3. set a new set of parameters, starting with the remaining
  #          parameters in $@ - including previously updated parameters
  #          with the '_' values interspersed, and then append the next
  #          updated key and inserted '_'  value.
  #     2.4  decrement the remaining count of parameters to update.
  local count=$#
  while [ $count -gt 0 ]; do
    local key="${1}"
    shift
    set -- "$@" ${key} '_'
    count=$(( $count-1 ))
  done

  # Declare the dict-simulating-a-set with the dict-as-set value assigned
  # to set_return_value:
  set_return_value="$(dict_declare_simple "$@")"
}

# Define a set_contains function that checks to see if a set (1st parameter)
# contains a value (2nd parameter). Directly returns true if the set contains
# the value or false if it does not.
set_contains() {
  local set="${1}"    # the haystack to search
  local value="${2}"  # the needle to find
  local maybe_in="$(dict_get_simple "${set}" "${value}")"
  if [ -n "${maybe_in}" ]; then
    true; return
  else
    false; return
  fi
}

# Define a set_add_members function that adds one or more members to a set.
# The set only increases its membership if a value is not already a member
# of the set. The updated set is returned in set_return_value.
set_add_members() {
  local set="${1}"
  shift
  # Once again convert set value arguments to dict key:value pair arguments
  local count=$#
  while [ $count -gt 0 ]; do
    local key="${1}"
    shift
    set -- "$@" ${key} '_'
    count=$(( $count-1 ))
  done
  # pass the set and converted entry values to dict_set_simple. Existing
  # entries will be overwritten, not performant but logically correct:
  set_return_value="$(dict_set_simple "${set}" "$@")"
}

# Define a set_union function that returns the union of two sets.
# Uses dict_for_each to append any values in 2nd set not in 1st set to
# the result which is initially assigned the value of the 1st set.
# Returns the resultant union set in set_return_value.
set_union() {
  set_return_value="${1}"
  dict_for_each "${2}" set_union_op
}

# Define set_union_op the per-member operation function for set_union.
# Called by dict_for_each for each of the members of the 2nd operand that
# set_union passes to dict_for_each. It calls set_add_members to ensure each
# one is in the result set in set_return_value.
set_union_op() {
  local member="${1}"
  set_add_members "${set_return_value}" "${member}"
}

# Define a set_intersection function returning the intersection of two sets.
# Uses dict_for_each to append any values in 2nd set also in 1st set to the
# result which is initially an empty set. dict_for_each is also passed the
# 1st operand set as an additional parameter to pass to each operation
# function call. Returns the resultant intersection set in set_return_value.
set_intersection() {
  set_declare
  dict_for_each "${2}" set_intersection_op "${1}"
}

# Define set_intersection_op the set_intersection per-member operation function.
# Called by dict_for_each for each of the members of the 2nd operand that
# set_intersection passes to dict_for_each. dict_for_each also passes the
# whole set intersection 1st operand set. A value is added to the resultant
# intersection set if it is in both the 1st operand set and the 2nd operand
# set, checked by seeing if the 1st operand set contains the 2nd operand set
# member value and if so the value is added to the result set in
# set_return_value.
set_intersection_op() {
  local member_of_2="${1}"
  local set_1="${4}"
  if set_contains "${set_1}" "${member_of_2}"; then
    set_add_members "${set_return_value}" "${member_of_2}"
  fi
}

# Define a set_print function that formats and outputs set objects to stdout.
# Sets up the print specification for dict_pretty_print and passes the set
# and specification to dict_pretty_print.
#
# The format is that used by Python sets:
#
#   { 'member-1', 'member-2', ..., 'member-N' }
set_print() {
  # Use backspace character as dict value suffix to backspace over
  # the dummy '_' set values. It is assumed tr is available but
  # only a basic echo that does not support -e or \e.
  local readonly ASCII_BS=$(echo '@' | tr '@' '\010')
  local print_spec="$( dict_declare_simple \
                       'dict_prefix' '{ ' \
                       'dict_suffix' ' }' \
                       'record_separator' ', ' \
                       'key_prefix' "'" \
                       'key_suffix' "'" \
                       'value_suffix' "${ASCII_BS}" \
                     )"
  dict_pretty_print "${1}" "${print_spec}"
}

#
# Using the set functions
# 

# Create and display a couple of sets:
set_declare 'Kayla' 'Johnny' 'Alexis' 'Bobby' 'Rose' 'Louis' 'Charlotte' 'Elijah'
friends="${set_return_value}"
set_declare 'Rose' 'Russell' 'Charlotte' 'Vincent' 'Natalie' 'Johnny' 'Brittany' 'Bobby'
collegues="${set_return_value}"
printf '%s' 'My  friends  are: '
set_print "${friends}"
printf '\n%s' 'My collegues are: '
set_print "${collegues}"
printf '\n\n'

# Add some new friends using set_add_members:
printf '%s\n' 'I have new friends Eugene and Diana!'
set_add_members "${friends}" 'Eugene' 'Diana'
friends="${set_return_value}"
printf '%s' 'My  friends  are now: '
set_print "${friends}"

# Add some new collegues contained in a set, added to existing friends
# using set_union:
set_declare 'Diana' 'Randy'
new_collegues="${set_return_value}"
printf '\n\n%s' 'New people '
set_print "${new_collegues}"
printf '%s' ' have just started on my team at work.'
set_union "${collegues}" "${new_collegues}"
collegues="${set_return_value}"
printf '\n%s' 'My collegues are now: '
set_print "${collegues}"
printf '\n\n'

# Obtain set of all friends and collegues. Some are both and therefore
# should only appear once. Thus we require the union of friends and collegues:
set_union "${friends}" "${collegues}"
all_friends_and_collegues="${set_return_value}"
printf '%s' 'All my friends and collegues are '
set_print "${all_friends_and_collegues}"
printf '\n'

# Obtain set of people who are both friend and collegue using set_intersection:
set_intersection "${friends}" "${collegues}"
both_friend_and_collegue="${set_return_value}"
printf '%s' 'My friends who are also collegues are '
set_print "${both_friend_and_collegue}"
printf '\n'
```

### Simulating a vector (single dimension array)

A vector or single dimension array is a container whose elements are identifed by an integer index, usually starting from 0 or 1. Some versions allow negative index values - either as a regular index value or one having special meaning such as index-from-the-end. Another characteristic of some implementations is that elements can only be efficiently added to the end of the vector - that is appended to the vector. Removing values from a vector or inserting at the beginning or in the middle of a vector are more involved and inefficient operations as they require copying the values around the removed / inserted element to close the gap or make space. Such a container can also be used as a sequence of values.

This example consists of support for simple vectors that are indexed from 0 to which values can be appended but should not be removed or inserted elsewhere. This is implemented by *dict*s which have sequentially increasing integer key values starting at 0. Each appended value has an index value equal to the size (number of elements) in the *dict* before the new element is appended. The vectors are used as ordered sequences which can be iterated over in the order values were added - either initially or by appending. The case differs from simulated sets - in which members are stored as dict keys - in that:

- values may be repeated (as they are stored as *dict* values)
- values many be nested *dict*s
- values can be accessed by index

The example demonstrates:

- using *dict* objects to simulate vectors used as sequences.
- more uses of `dict_declare`, `dict_set` and `dict_for_each`.
- using `dict_size` to obtain the number of entries in a *dict*.

```bash
#!/bin/sh

# Include the dict code. This assumes dict.sh is either in the same directory
# as the executing script or on the PATH. If not then use the dict.sh path:
. dict.sh

# Define functions to work with dicts simulating vectors. Most functions return
# their value in the gobal vector_return_value variable, which we initialse to
# a known, empty, state here:
vector_return_value=''

# Define a vector_declare function that wraps a call to dict_declare.
# Like dict_declare/dict_declare_simple vector_declare takes an optional,
# variable, number of values to initialise the new vector-dict with, however
# each argument is a *whole* vector element which must be paired with a
# 0 based index key value before being passed to dict_declare. dict_declare
# is called rather than dict_declare_simple as the values may be dicts.
# The new vector-dict is returned in vector_return_value.
vector_declare() {
  # Insert a 0 based index value before the passed vector element values to
  # convert to dict key:value entry argument pairs. This is done carefully
  # as we are consuming and modifying $@ at the same time! The method is:
  #   1. set the count of how many parameter values $@ contains _before_
  #      we start. This is because the number of parameters varies as
  #      each index is added.
  #   2. set the initial index value to 0.
  #   3. iterate for each parameter originally in $@ - i.e. count times:
  #     3.1. grab the next vector element value, which is the next dict value.
  #     3.2. remove this value from $@
  #     3.3. set a new set of parameters, starting with the remaining
  #          parameters in $@ - including previously updated parameters
  #          with their preceding index key values, and then append the
  #          next updated index key and vector element value.
  #     3.4  decrement the remaining count of parameters to update
  #     3.5  increment the index value
  local count=$#
  local index=0
  while [ ${count} -gt 0 ]; do
    local value="${1}"
    shift
    set -- "$@" "${index}" "${value}"
    count=$(( ${count}-1 ))
    index=$(( ${index}+1 ))
  done

  # Declare the dict-simulating-a-vector with the dict-as-vector value
  # assigned to vector_return_value:
 vector_return_value="$(dict_declare "$@")"
}

# Define a vector_append function that wraps a call to dict_set.
# vector_append takes one or more element values to append to the passed 
# vector-dict, however each value argument is a *whole* vector element which
# must be paired with the correct index key value before being passed to
# dict_set. dict_set is called rather than dict_set_simple as the values may
# be dicts. The new vector-dict is returned in vector_return_value.
vector_append() {
  local vector="${1}"
  shift
  # Once again convert vector element value arguments to dict key:value pair
  # arguments, this time the initial index is the number of elements in the
  # vector-dict:
  local count=$#
  local index=$(dict_size "${vector}")
  while [ ${count} -gt 0 ]; do
    local value="${1}"
    shift
    set -- "$@" "${index}" "${value}"
    count=$(( ${count}-1 ))
    index=$(( ${index}+1 ))
  done

  # pass the vector and converted entry values to dict_set:
  vector_return_value="$(dict_set "${vector}" "$@")"
}

#
# Using the vector functions
#

# Requires Linux with /proc file system, basic grep, awk and sleep.
# Collect samples of the /proc/meminfo Dirty memory count over several
# seconds and display a simple graph:

# Declare vector with initial sample value
printf '%s\n' 'Collecting dirty memory kB samples from /proc/meminfo...'
ASCII_CR=$(printf '\015')
sample="$(grep "Dirty" /proc/meminfo | awk -F" " '{print$2}')"
vector_declare ${sample}
dirty_mem_kB="${vector_return_value}"

# Collect remaining samples at ~1 second intervals
# Remember maximum sample value - for use in scaling values to fit graph
remaining_samples=29
max_sample=${sample}
while [ ${remaining_samples} -gt 0 ]; do
  printf '%s' "${ASCII_CR}Samples to go: ${remaining_samples}   "
  sleep 1
  sample="$(grep "Dirty" /proc/meminfo | awk -F" " '{print$2}')"
  if [ ${sample} -gt ${max_sample} ]; then
    max_sample=${sample}
  fi
  vector_append "${dirty_mem_kB}" ${sample}
  dirty_mem_kB="${vector_return_value}"
  remaining_samples=$(( ${remaining_samples}-1 ))
done
printf '%s\n' "${ASCII_CR}                                      "

# The graph will be 'drawn' in another vector with each value representing
# one line of the graph. Sample values extend up the y-axis and samples
# are ranged along the x-axis. This would be the typical arrangement for a
# graph but tricky on a line based terminal where the obvious
# arrangement is to output one sample value representation per line.
readonly graph_lines=30
readonly graph_sample_scale_factor=$(( ${max_sample}/${graph_lines} ))

# Set up the graph-buffer vector, populating the graph as we go by calling
# dict_for_each to iterate through the samples to determine whether a marker
# or spacer should be left for each sample depending on its value and the
# 'y-value' of the graph line.

# Define a graph_line_op function that is called for each sample for
# each line with sample value as parameter 2 and the y-coordinate passed
# as parameter 4 (the ${lines_remaining} argument), running from
# ${graph_lines}-1 to 0
graph_line_op() {
  local sample=${2}
  local y_coord=${4}
  local y_value=$(( ${y_coord}*${graph_sample_scale_factor} ))
  if [ ${sample} -ge ${y_value} ]; then
    graph_line="${graph_line}* "
  else
    graph_line="${graph_line}  "
  fi
}

vector_declare
graph="${vector_return_value}"
lines_remaining=${graph_lines}
while [ ${lines_remaining} -gt 0 ]; do
  # set the graph line with y-axis depiction, then add sample points
  graph_line='| '
  lines_remaining=$(( ${lines_remaining}-1 ))
  dict_for_each "${dirty_mem_kB}" graph_line_op ${lines_remaining}
  vector_append "${graph}" "${graph_line}"
  graph="${vector_return_value}"
done
# Finish the graph by adding the x-axis depiction to the graph vector
vector_append "${graph}" \
              '*--------------------------------------------------------------'
graph="${vector_return_value}"

printf '%s\n' "${max_sample}kB"
# Finally output the graph, again using dict_for_each and an operation
# function that simply echos the line entry value, passed in parameter 2:
graph_print_line_op() {
  printf '%s\n' "${2}"
}

dict_for_each "${graph}" graph_print_line_op

```

---

Copyright © 2022 R. E. McArdell

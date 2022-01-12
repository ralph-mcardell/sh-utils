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
- `getconf ARG_MAX` to determine limit of maximum possible number of  
  command-line arguments

## Installation

Ensure that the *parseargs.sh* and the *dict.sh* file in the repository *lib* directory are in a known location and access by specifying the pathname or are on the process PATH. *parseargs.sh* assumes *dict.sh* is in the same directory as *parseargs.sh* or can be found on the PATH.

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
- add arguments to the parser with `parseargs_add_argument` specifying per-argument attributes. 
- sub-parsers, for use with `sub_command` and `sub_argument` arguments, can be added with `parseargs_add_sub_parser`. 
- when the top level argument parser is complete it can be used to parse  arguments, typically `$@`, with `parseargs_parse_arguments`.
- `parseargs_parse_arguments` returns a *dict* containing the argument values except in the case of: `help` or `version` action optional arguments being given when the requested information is output to *stdout* after which the `parseargs_parse_arguments` call process exits.
- errors detected during any *parseargs* function call causes an error message to be output to *stderr* and the call process to exit.

### Comparison with Python's *argparse* module

As has been mentioned *parseargs* took inspiration from the Python *argparse* module. Most of the basic *argparse* functionality has been implemented. The following features of *argparse* are not implemented by *parseargs*:

- the *argparse* *ArgumentParser* constructor's *prefix_chars* parameter has not been implemented. The *parseargs* prefix character is fixed as hypen: single for short optional arguments (e,g, `-o`) and double for long optional arguments (e.g. `--option`).
- parent parsers as supported by the *argparse* *ArgumentParser* constructor's *parents* parameter have not been implemented in *parseargs*. See below for obtaining limited similar effects.
- custom help formatters, as supported by the *argparse* *ArgumentParser* constructor's *formatter_class* parameter is not implemented for *parseargs*.
- explicit printing and formatting of help and usage is not supported by  *parseargs*.
- *parseargs* has no support for resolving conflicting optionals a la the *argparse* *ArgumentParser* constructor's *conflict_handler* parameter.
- *parseargs* does not support abbreviated long optionals.
- control of how errors are handled. Errors during execution of *parseargs* function calls *always* exits the call-process (note: this will usually be different to the process of the caller as *parseargs* functions that produce errors are designed to be called using *Command Substitution*).
- reading arguments stored in a file as supported by the *argparse* *ArgumentParser* constructor's *fromfile_prefix_chars* parameter is not supported by *parseargs*.
- argument values are not typed - so the *argparse* `add_argument` *type* parameter functionality has not been implemented for *parseargs*. All argument values are strings.
- *parseargs* does not support custom argument actions as *argparse* does with  *Action classes*.
- explcitly setting (or getting) argument defaults other than when creating a parser or adding an argument specification is not supported by *parseargs*.
- *parseargs* does not support partial parsing.
- argument groups are not supported by *parseargs*.

Additionally the way parser argument specifications determine whether an argument is positional or optional differs. Rather than the form of a *name or flags* parameter or attribute value indicating what type of argument it is *parseargs* has separate attributes for positional, short and long optionals:

- *name* provides the name for a positional parameter.
- *short* specifies a short optional argument character with *no leading hyphen*.
- *long* specifies a long optional argument string with *no leading hyphens*.

*name* cannot be given for the same argument's specification together with either  *short* or *long*. Both *short* and *long* can be given for the same optional argument's specification.

#### *parseargs* parent parsers

While *parseargs* does not support specifying one or more parent argument  parsers when creating a parser with something akin to the *argparse* *ArgumentParser* constructor's *parent* parameter it is possible to achieve a limited form of the functionality.

A *parseargs* argument parser is a *dict* and *Sh Util* *dicts* are just specially formatted strings. This means *parseargs* argument parsers can be cloned by simply copying them. Hence any *parseargs* argument parser can be used as a parent of another by copying the 'parent' parser to a new 'child' parser. Any changes to the parsers following the copy operation will then be independent of each other. Note that such copies can be made by assigning one *parseargs* argument parser variable to another variable or by passing a *parseargs* argument parser to a *parseargs* argument parser updating function and storing the result in a different variable.

#### *parseargs* sub-command and sub-parser support

*parseargs* supports sub-commands via the *parseargs* specific *sub_command* and *sub_argument* actions and the `parseargs_add_subparser` function.

Unlike the *argparse* design, argument specifications must be explicitly added to the *super* (outer) argument parser with a *sub_command* or *sub_argument* action, whereby sub-parsers can be associated with an argument via their *destination* attribute value (which may have been provided explicitly or derived from an argument specification's *name* or *long* attribute values).

Sub-parsers are normal *parsearg* argument parsers created with `parseargs_new_argument_parser`, populated and then added to the *super* parser with the `parseargs_add_subparser` function, rather than being obtained from some sub-parser creation function then populated. Note that *parseargs* sub-parsers are populated with the usual *parseargs functions: `parseargs_add_argument` and `parseargs_add_sub_parser` (implying it is possible to create argument parsers that are used as sub-sub-parsers and so on).

Unlike *argparse*, any argument and number of arguments can be specified to have a *sub_command* action. However in practice if more than one argument is so specified then it will not be possible to parse a command line properly as once parsing has entered sub-command processing all remaining arguments parsed are assumed to be parsed with the selected sub-parser.

Similarly, any number of *optional* arguments can be specified to have *sub_argument* actions. In this case having multiple optional arguments specified to be parsed with *sub_argument* actions makes sense. This is because arguments parsed with the *sub_argument* action only parse one argument with the selected sub-parser at a time, switching back to the outer, *super* parser once one argument's set of values has been parsed.

#### Intermixed parsing and the meaning of --

*parseargs* parses arguments according to the specifications of an argument parser with the `parseargs_parse_arguments` function. This is sort of a combination of the Python *argparse* `ArgumentParser.parse_args` and `ArgumentParser.parse_intermixed_args` methods in that:

- all arguments are parsed. No partial parsing.
- positional and optional arguments can be freely intermixed.
- invalid arguments (e.g. unknown optional argument identifier) or too few positional arguments are errors.
- extra positional arguments are neither returned nor a hard error but are ignored and produce a warning message on *stderr*.
- an argument with just the value `--` on its own can be used to terminate argument value parsing and move to parsing the next argument.

More on the last point about the use of `--`: in *argparse* argument parsing `--` can be used to indicate the end of optional arguments and the start of positional arguments.

In *parseargs* argument parsing `--` is used to force the termination of one argument's values so parsing moves on to the next argument. This might be required for example to terminate multiple arguments with open-ended or optional *nargs* attribute values - `*`, `+` or `?`.

For example:

`--maybe_has_argument whose_argument_value_am_i ...`

If the argument specification for `maybe_has_argument` specifies a *nargs* attribute value of *?*, that is the optional argument might or might not have a value, then is `whose_argument_value_am_i` a value provided to the `maybe_has_argument` optional argument so it has 1 argument value or part of the next positional argument and `maybe_has_argument` has no argument value? In fact *parseargs* associates values with the current argument while it is expecting values as indicated by the *nargs* attribute value, or its absense.

This is all fine and dandy for arguments with a fixed number of argument values but as we have seen above is problematic when trying to determine the end of argument values associated with one argument specification when the number of values is not fixed. To get around this limitation `--` can be inserted after the last value associated with one argument specification before the start of the next. So modifying the above example by adding `--` before `whose_argument_value_am_i` thus:

`--maybe_has_argument -- whose_argument_value_am_i ...`

would force `whose_argument_value_am_i` to be associated with the next expected positional argument while `maybe_has_argument` has no provided argument value and so, as it is an optional argument, the value will be provided by the `maybe_has_argument` argument specification's *const* attribute value.

Note that it is an error to find what appears to be an optional argument identifier (i.e. a value starting with `-` that is not `--`) when parsing argument values associated with an argument specification.


## Reference

### Function synopsis

| Function name | Description |
| ------------- | ----------- |
| `parseargs_new_argument_parser` | Create a new *parseargs*' argument parser. |
| `parseargs_add_argument` | Add a new argument specification to a *parseargs*' argument parser with the specified attributes. |
| `parseargs_add_sub_parser` | Add a *parseargs*' argument parser as a sub-parser of another *parseargs*' argument parser. |
| `parseargs_parse_arguments` | Parse arguments according to the specifications of a *parseargs*' argument parser. |
| `parseargs_is_argument_parser` | Check to see if the passed value represents a *parseargs*' argument parser. |

### `parseargs_new_argument_parser`

`parseargs_new_argument_parser` is used to create argument parsers, which are specially formatted *dict*s (which are specially formatted strings).

`parseargs_new_argument_parser` takes 0 or more pairs of arguments that provide *attribute-name* *attribute-value* argument pairs. It is valid to not provide values for any attributes in which case defaults will be used.

`parseargs_new_argument_parser` is designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 2n-1  | (optional) attribute name, n>=1. |
| 2n    | (optional, must be provided if argument *2n-1* provided) attribute value, n>=1. |

The following attributes are supported:

| Attribute name | Value description |
| ----------------- | ----------- |
| 'prog'    | Name of program as used in help (default: $0 ). |
| 'usage'    | String describing program usage (default: deduced from arguments added to parser). |
| 'description'    | Text displayed before argument help (default: ''). |
| 'epilogue'    | Text displayed after argument help (default: ''). |
| 'argument_default'    | Global default value for arguments (default: ''). |
| 'add_help'    | Boolean. Add -h / --help option to parser (default: true). |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *parser* value containing specified attributes and an argument specification for *help* option unless `'add_help'` `'false'` specified. The returned *parser* can be used with the other *parseargs* functions and if passed to `parseargs_is_argument_parser` then `parseargs_is_argument_parser` returns *true*. |  |
| 1 (fail) | empty string. | Failed to add help optional argument to new parser: ${reason}  [*See `parseargs_add_argument` description for possible reasons*]. |

### `parseargs_add_argument`

`parseargs_add_argument` is used to add a specification of an argument to be parsed to a *parseargs* argument *parser* orginally returned from `parseargs_new_argument_parser`.

`parseargs_add_argument` is passed an argument *parser* and a variable number of *attribute-name* *attribute-value* argument pairs that specify the argument: positional vs optional, long and/or short option identifiers, what action to take on encounting the argument, where to store the argument value or values if it has such and so on.

`parseargs_add_argument` is designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | Argument *parser* to add argument specification to. |
| 2n   | attribute name, n>=1. |
| 2n+1 | attribute value, n>=1. |

The following attributes are supported:

| Attribute name | Value description |
| ----------------- | ----------- |
| 'destination'    | Name of entry key for argument stored value(s) in the result *dict* from parsing arguments. (default:<br/> - **'name'** attribute value for  positional arguments  <br/> - **'long'** attribute value for optional arguments that have a long option form. <br/> - **none** for optional arguments that only have a short option form; in these cases a 'destination' attribute value is required.) |
| 'name'    | Name for a positional argument. If given then neither 'long' or 'short' attributes can be given - an argument cannot be both positional and optional. (default: none). |
| 'long'    | Long optional argument string (e.g. 'longopt' for option --longopt). Can be specified with 'short' (default: none). |
| 'short'    | Short optional argument character (e.g. 'x' for option -x).   Can be specified with 'long'. (default: none).|
| 'action'    | Action to perform for argument (see below). (default: *store* unless *version* attribute specified when the default is *version*).|
| 'nargs'    | Number of values comprising this argument. Defaults to 1 argument. 0 implies a flag value. Any other positive integer value explicitly given, including 1, results in argument values being stored in a *dict*. Maximum value is `ARG_MAX/2`. The following special values are accepted:<br/>**'?'** : 0 or 1 argument values may be given. If no value is given then a predefined value is substituted. For positional arguments this value is either an argument specific default or parser global default attribute value. For optional arguments the substituted value is provided by a *const* argument attribute value.<br/> **'*'** : 0 or more argument values, stored in a possibly empty *dict*.<br/> **'+'** : 1 or more argument values, stored in a *dict*. |
| 'const'    | A constant value to be used in conjunction with certain action 1 values (*nargs* value of '?'). (default: none) |
| 'default'    | A default value to be used in cases of the argument missing attribute values and for optional arguments that specify 0 or 1 values (*nargs* value of '?'). (default: none => use *parser*'s global *argument_default* value if set) |
| 'required'    | A true/false flag value indicating an optional argument is required and must be provided (possibly via a default value). Note: positional arguments are always required, even if they have *nargs* of '?' where a non provided value is provided by the *default* attribute value. (default: false) |
| 'choices'    | Specify a set of strings that are valid choices as values for an argument. The *choices* attribute value is a *dict* with each entry key a choice and each entry value any non-empty string - typically '_'. (default: none) |
| 'version'    | String value displayed by a *version* action argument. If the version attribute is set and no action is given then then a version action is assumed and not the usual default of a *store* action. (default: none) |
| 'help'    |  Text describing the argument. Used when processing a *help* action argument in the help output. (default: none) |
| 'metavar'    |  String to use in help output as the basis for this argument's value(s) name(s) rather than the explicit or implict destination attribute value. (default: none) |

The following argument actions are supported:

| Action name | Action description |
| ----------------- | ----------- |
| 'store'    | (default if no *version* attribute set). Store the argument value(s) as an entry in the parse results *dict* with a key value provided by the explicitly given or implcitly deduced argument specification *destination* attribute value. |
| 'append'    | Store the argument value(s) in an entry in the parse results *dict* with a key value provided by the explicitly given or implcitly deduced argument specification *destination* attribute value. The entry value is a *dict* in which each occurrance of an argument value(s) to be stored in the result slot is appended to the *dict*. Each entry in the value *dict* has a key index value starting at 0 and a value of the parsed argument value(s). |
| 'entend'    | Same as the *append* action unless an argument value is a *dict* (with explicit *nargs* values for example) in which case each entry value in the argument value(s) *dict* is appended individually to the result *dict* entry value *dict* rather than being added as a whole nested *dict*. |
| 'store_const'    | Store the single constant value given by the argument specification *const* attribute. Note that this only really makes sense if multiple optional arguments have the same result *dict* entry key *destination* attribute value. |
| 'append_const'    | Store the single constant value given by the argument specification *const* attribute by appending to any existing values stored at this destination. Note this only really makes sense if multiple optional arguments have the same result *dict* entry key *destination* attribute value. |
| 'store_true'    | Special form of *store_const* that stores a *true* value for the result entry having a *destination* attribute key. |
| 'store_false'    | Special form of *store_const* that stores a *false* value for the result entry having a *destination* attribute key. |
| 'count'    | Store the count of the number of occurences of an optional argument flag. |
| 'version'    | (default if *version* attribute given for argument). Output version information provided by the *version* argument specification attribute. |
| 'help'    | Output help for program using the various parser, argument specifications and sub-parsers help related attribute values. |
| 'sub_command'    | Hand parsing over to a sub-parser (see *parseargs_add_sub_parser*). The sub-parser is selected by the argument *destination* attribute and the value of the first value of the argument. This mean that practically a sub-command action argument has to be the last argument parsed as all remaining values will be consumed either as the sub-command name (that is the sub-parser id) or the sub-command arguments parsed by the selected sub-parser. The result value is the result values *dict* from the sub-parse operation. Examples:<br/>**Positional sub-command:**<br/>&nbsp;&nbsp;&nbsp;&nbsp;cmd -a x -b y pos1 pos2 subcmd \\<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;--subopt this subpos1 subpos2<br/>**Optional sub-command**<br/>&nbsp;&nbsp;&nbsp;&nbsp;cmd -a x -b y pos1 pos2 --action subcmd \\<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;--subopt this subpos1 subpos2 |
| 'sub_argument'    | Similar to sub-command except that it only applies to optional arguments, and only a single sub-parser argument is parsed for each occurence of a sub-argument option.  e.g:<br/>&nbsp;&nbsp;&nbsp;&nbsp;cmd -r example.com -p /home/theuser/workdir \\<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-T stage1 --opt1 value -T stage1 --opt2 data \\<br/>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;-T stage2 --optpath /path/to/somedir -T stage2 pos1 |

**Note:** positional arguments can only have *store* (the default) or *sub_command* actions.

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | Copy of the *parser* value passed as parameter 1 updated with the added argument specification. |  |
| 1 (fail) | empty string | First argument passed to parseargs_add_argument is not an argument parser type. |
| 1 (fail) | empty string. | Both name and long/short specified. Argument cannot be both positional and optional. |
| 1 (fail) | empty string. | Argument \${attr} attribute specified more than once. [where \${attr} is the name of an attribute] |
| 1 (fail) | empty string. | nargs value '\${num_args}' invalid. Must be integer in the range [1, ARG_MAX/2], '?','*' or '+'. [where \${num_args} is the value provided for the *nargs* attribute] |
| 1 (fail) | empty string. | Argument choices attribute value is not a dict(ionary). |
| 1 (fail) | empty string. | Unrecognised parser argument attribute '\${attr}'. [where \${attr} is the value provided where an attribute name was expected] |
| 1 (fail) | empty string. | Unable to deduce destination name for argument value from destination, name or long attribute values. |
| 1 (fail) | empty string. | Action attribute value '\${action}' cannot be used for positional arguments '\${dest}'. [where \${action} is the value provided for the *action* attribute and \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | A default attribute value is required for optional positional argument (nargs=?) '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | A const attribute value is required for optional arguments with optional value (nargs=?) '${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Argument short option attribute value '\${short_opt}' is not a single character. [where \${short_opt} is the value provided for the *short* attribute] |
| 1 (fail) | empty string. | Argument short option attribute value '${short_opt}' given previously. [where \${short_opt} is the value provided for the *short* attribute] |
| 1 (fail) | empty string. | Argument long option attribute value '${long_opt}' given previously. [where \${long_opt} is the value provided for the *long* attribute] |First
| 1 (fail) | empty string. | None of name, long or short attributes provided for argument. |
| 1 (fail) | empty string. | Cannot specify {nargs \| const} attribute value for arguments with 'sub_command' or 'sub_argument' action attributes '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | A const attribute value is required for arguments with 'store_const' or 'append_const' action attribute '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify nargs attribute value for arguments with 'store_const' or 'append_const' action attribute '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify nargs attribute value for arguments with 'store_true' or 'store_false' action attributes '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify a default or const attribute value for arguments with 'store_true' or 'store_false' action attributes '${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify a const or nargs attribute value for arguments with 'count' action attribute '${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | A version attribute with a value supplying the version text is required for arguments with 'version' action attribute '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify const, default, required, choices or nargs attribute values for 'version' action attributes '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Cannot specify const, default, required, choices, version or nargs attribute values for 'help' action attributes '\${dest}'. [where \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Unrecognised action attribute value '\${action}' for argument '${dest}'. [where \${action} is the value provided for the *action* attribute and \${dest} is the deduced destination key for the argument's value(s)] |
| 1 (fail) | empty string. | Number of metavar values does not match number of arguments (nargs=\${num_args}) for argument '\${dest}'. [where \${num_args} is the value provided for the *nargs* attribute and \${dest} is the deduced destination key for the argument's value(s)] |

### `parseargs_add_sub_parser`

`parseargs_add_sub_parser` is used to add as a sub-parser an existing, fully specified *parseargs* argument *parser* orginally returned from `parseargs_new_argument_parser` to another such *parseargs* argument *parser*.

Sub-parsers are used by argument actions *sub_command* and *sub_argument* to hand parsing over to a sub-parser once a sub-parsing id name (or alias for the id) has been parsed to indicate which sub-parser should be used to parse the following argument or arguments.

The arguments passed to `parseargs_add_sub_parser` need to specify both which parser and which argument of that parser the sub-parser is associated with. So in addition to the *parseargs* argument *parser* to add the sub-parser to, the *destination* attribute value of the argument the sub-parser is associated with is required. Similarly, in addition to the sub-parser *parseargs* argument *parser*, the string value used to identify which sub-parser to hand off parsing to (the *sub-command* name) is also passed to `parseargs_add_sub_parser`. Finally, if the *sub-command* has aliases (for example a 'remove' sub-command might have aliases 'delete', 'rm' and 'del') then these are also passed to  `parseargs_add_sub_parser`.

Note that as all values are pasesd by value changes made to a sub-parser after passing to `parseargs_add_sub_parser` *will not be reflected in the sub-parser used by the parent parser*.

`parseargs_add_sub_parser` is designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | Argument *parser* to add sub-parser to. |
| 2    | *destination* attribute of argument the sub-parser is to be associated with. |
| 3    | id name string for the sub-parser (the *sub-command* name). |
| 4    | the sub-parser argument *parser*. |
| 5+   | (optional) alias names for the sub-parser id. |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | Copy of the *parser* value passed as parameter 1 updated with the added sub-parser, sub-parser id and aliases. |  |
| 1 (fail) | empty string | First argument passed to parseargs_add_argument is not an argument parser type. |
| 1 (fail) | empty string | Forth argument passed to parseargs_add_argument is not an argument parser type. |

## `parseargs_parse_arguments`

`parseargs_parse_arguments` is used to parse a set of arguments according to the description of accepted argument forms contained in a *parseargs* argument *parser*.

If an immediate action argument is parsed - one having an action type of *help* or *version* - then these are performed immediately and parsing terminated.

Otherwise, assuming no errors are raised, parsed argument values are stored and returned in a *dict* (see the *sh_utils/lib/dict.sh* library), which may contain nested *dicts* for arguments having multiple values. See the action descriptions in the `parseargs_add_argument` reference section for details on what actions are available and what effect they have on parsing arguments.

Following the parsing of immediatly provided argument values the results are fixed up with default values and validated that required values are present and argument values required to be from a set of choice values are members of their associated choices set.

`parseargs_parse_arguments` is designed to be called using *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | Argument *parser*  describing arguments to be parsed. |
| 2+   | Arguments to parse. To parse command line options pass script top level (ie. not in a function) value of $@.  |

#### Return values

| $? | stdout | fail reasons (error message on stderr) |
| -- | ------ | ------------ |
| 0        | *dict* containing argument values with values associated with argument *destination* keys. |  |
| 1 (fail) | empty string | First argument passed to parseargs_add_argument is not an argument parser type. |
| 1 (fail) | empty string | Unknown short option -\$\{opt}. [where ${opt} is a short option character] |
| 1 (fail) | empty string | Unknown long option --\$\{opt}. [where ${opt} is a long option string] |
| 1 (fail) | empty string | \${arg}: "${subcmd}" is not a known sub-command. [where \${arg} is an argument description and \${subcmd} is a sub-parser sub-command id or alias] |
| 1 (fail) | empty string | \${arg} did not have a single sub-argument command argument value. [where \${arg} is an argument description] |
| 1 (fail) | empty string | \${arg} did not have a single sub-command command argument value. [where \${arg} is an argument description] |
| 1 (fail) | empty string | \${arg} is missing an argument value. [where \${arg} is an argument description] |
| 1 (fail) | empty string | Required option \${opt} was not provided. [where \${opt} is a required optional argument name or character] |
| 1 (fail) | empty string | Value '\${v}' is not a valid choice for ${opt}. [where \${v} is an argument value and \${opt} is an optional argument name or character] |
| 1 (fail) | empty string | (internal) Argument specification key for short option \-\${opt} not found. [where ${opt} is an option character; Indicates a corrupt or invalid parser] |
| 1 (fail) | empty string | (internal) \${arg}: no attributes specifying this argument. [where \${arg} is an argument description; Indicates a corrupt or invalid parser] |
| 1 (fail) | empty string | (internal) Unexpected unrecognised action '${action}' [where \${action} is an invalid argument specification action attribute value; Indicates a corrupt or invalid parser] |
| 1 (fail) | empty string | (internal) \${arg} : unrecognised missing argument value action '${on_missing}'. [where \${arg} is an argument description and \${on_missing} is an indicator of what to do if an expected value is missing; Indicates a corrupt or invalid parser] |
| 1 (fail) | empty string | (internal)  sub-command/sub_argument arguments for '${dest}' are missing the '\_\_sub_command__' entry. [where \${dest} is the destination key for the argument with missing internal parts; Indicates a corrupt or invalid parser] |

## `parseargs_is_argument_parser`

`parseargs_is_argument_parser` is used to check a value (of a variable) represents a *parseargs* argument *parser*.

`parseargs_is_argument_parser` is intended to be called directly and *not* via *Command Substitution*.

#### Parameters

| Parameter number| Description |
| --------------- | ----------- |
| 1    | Value to check to see if it is a*parseargs* argument *parser*. |

#### Return values

*true* if the passed value appears to be a *parseargs* argument *parser*.

*false* if the passed value does not appear to be a *parseargs* argument *parser*.

---

Copyright © 2022 R. E. McArdell

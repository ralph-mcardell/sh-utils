# Sh_test : Simple unit tests for sh script library modules

The *sh_utils* shell language library module provides a basic unit test framework. Its primary reason to be was the need to provide unit tests for the other shell language library modules in *sh_utils*.

## Installation

Ensure that the *sh_test.sh* file in the repository *lib* directory is in a known location and access by pathname or is on the process PATH.

## To use *sh_test.sh*

In a shell script file that wishes to make use of *sh_test.sh* facilities include it with the source include dot operator either by pathname:

`. /path/to/sh_test.sh`

or just by name if you have put *sh_test.sh* on the process' PATH:

`. sh_test.sh`

[Note: the `source` command is a GNU *bash* specific feature.]

## Using to write unit tests

The usage is fairly simple:

- write test functions making use of *sh_test* assertion functions.
- register/execute each test function with the `TEST` *sh_test* function.
- call the *sh_test* `PRINT_TEST_COUNTS` function at the end.
- run the test *sh* script.

Note that test function are presumed to neither require nor return any values.

### Assertion Functions

There are two types of assertion:

- **REQUIRE** assertions test an expression and exits with a return code of 1 if it fails, calling `PRINT_TEST_COUNTS` just before exiting.
- **CHECK** assertions test an expression and continue even in the light of a fail.

In both cases the test run counters are updated, these are:

- number of tests
- number of passed tests
- number of failed tests
- number of assertions
- number of passed assertions
- number of failed assertions

They are output to *stdout* in a formatted manner by `PRINT_TEST_COUNTS`.
In addition, if requested (by *sh_test* commandline option), test execution times are also recorded (and the total time output by `PRINT_TEST_COUNTS`).

#### Check expression assertions

The functions in this set are:

- `CHECK`
- `REQUIRE`
- `CHECK_FALSE`
- `REQUIRE_FALSE`

These functions accept 1, 2 or 3 arguments interpreted as a Boolean expression:

- A single argument is interpreted as a Boolean value:
    `CHECK_FALSE "${result}"`
- Two arguments are presumed to be a unary operator followed by the value of the operand:
    `REQUIRE -z "${actual:+x}"`
- Three arguments are presumed to be an operand value, a binary operator followed by the second operand value:
    `CHECK $? -eq 1`

For `CHECK` and `REQUIRE` the assertion passes if the expression evaluated true.

For `CHECK_FALSE` and `REQUIRE_FALSE` the assertion passes if the expression evaluated false.

#### String containing substrings assertions

The functions in this set are:

- `CHECK_CONTAINS_ALL`
- `REQUIRE_CONTAINS_ALL`

They take a string argument followed by one or more substrings:

  `CHECK_CONTAINS_ALL "${returned_error}" "ERROR" "invalid"`

The assertions pass if all substrings appear in the first string argument.

### The `TEST` function

*sh_test* is simple and there is no automatic test function registration. Instead the name of each function that forms part of the test suite is passed to the `TEST` function which executes the test function around performing the various test run book keeping. As test functions are executed immediately by the `TEST` function they are executed in the order calls to the `TEST` function are executed.

Example:
```bash
TEST calling_api_function_abc_with_negative_value_is_an_error
```

### The `PRINT_TEST_COUNTS` function

As mentioned already *sh_test* is simple and printing the summary test statistics to *stdout* is done manually by calling `PRINT_TEST_COUNTS`, typically at the end of the test suite *sh* script.

The output displays the values of the accumulated counts:

```
Performed 44 tests / 392 assertions. Passed 44 tests / 392 assertions. Failed 0 tests / 0 assertions.
```

The total elapsed time is also output if test timings were requested (on the commandline):

```
Performed 44 tests / 392 assertions. Passed 44 tests / 392 assertions. Failed 0 tests / 0 assertions in .499197083 seconds.
```
## Running test suites - command line options

A *sh* script that uses uses *sh_test* can be executed in the normal manner:

- make the script executable
- execute from commandline etc.

When doing so *sh_test* behaves in a default manner:

- only output information on failed assertions
- does not record / output test timings

At present there is no way to filter which tests are executed - any test function whose name is passed to the `TEST` function will be executed.

### Command line options

*sh_test* provides the following options to test *sh* scripts:

- `-s`, `--success` : report successful as well as failed assertions.
- `-t`, `--timings` : report rough per test and total elapsed timings. This includes time executing *sh_test* functions as well as time executing test function code.
- `-h`, `--help`    : print the command line options with description and exit.
- `-v`, `--version` : print sh-test version and exit.

---
Copyright © 2021 R. E. McArdell

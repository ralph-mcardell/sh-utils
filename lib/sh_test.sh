#!/bin/sh
# Copyright (c) 2022 Ralph. E. McArdell
# All rights reserved.
# Licensed under BSD 2-Clause License - see LICENSE.md for full text.
#
# Basic unit testing framework for sh (sh not bash) script 'units' - functions.
#

# @brief Require condition is true and exit if not.
#
# Test the passed expression, update the test and assert counts as appropriate,
# and if false print the test count values and exit with a return code of 1.
#
# Call forms:
#
# REQUIRE ${actualboolvalue}
# REQUIRE uo ${actualvalue}
# REQUIRE ${actualvalue} bo ${expectedvalue}
#
# where:
#  uo is a unary operator such as -z or -n
#  bo is a binary operator such as = or -lt
#
# @param 1       : A true/false value if only 1 parameter passed.
#                  A unary test operator (e.g. -z) if 2 parameters passed.
#                  Actual test value if 3 parameters passed.
# @param 2 (opt) : Actual test value if 2 parameters passed.
#                  Binary test operator (e.g. -ge) if 3 parameters passed.
# @param 3 (opt) : Expected value actual value tested against using.
#                  binary operator.
REQUIRE() {
  __sh_test_assert__ "REQUIRE" false "$@"
}

# @brief Expect condition to be true.
#
# Test the passed expression, update the test and assert counts as appropriate.
# Failure if expression false.
#
# Call forms:
#
# CHECK ${actualboolvalue}
# CHECK uo ${actualvalue}
# CHECK ${actualvalue} bo ${expectedvalue}
#
# where:
#  uo is a unary operator such as -z or -n
#  bo is a binary operator such as = or -lt
#
# @param 1       : A true/false value if only 1 parameter passed.
#                  A unary test operator (e.g. -z) if 2 parameters passed.
#                  Actual test value if 3 parameters passed.
# @param 2 (opt) : Actual test value if 2 parameters passed.
#                  Binary test operator (e.g. -ge) if 3 parameters passed.
# @param 3 (opt) : Expected value actual value tested against using.
#                  binary operator.
CHECK() {
  __sh_test_assert__ "CHECK" false "$@"
}

# @brief Require condition is false and exit if not.
#
# Test the passed expression, update the test and assert counts as appropriate,
# and if true print the test count values and exit with a return code of 1. 
#
# Call forms:
#
# REQUIRE_FALSE ${actualboolvalue}
# REQUIRE_FALSE uo ${actualvalue}
# REQUIRE_FALSE ${actualvalue} bo ${expectedvalue}
#
# where:
#  uo is a unary operator such as -z or -n
#  bo is a binary operator such as = or -lt
#
# @param 1       : A true/false value if only 1 parameter passed.
#                  A unary test operator (e.g. -z) if 2 parameters passed.
#                  Actual test value if 3 parameters passed.
# @param 2 (opt) : Actual test value if 2 parameters passed.
#                  Binary test operator (e.g. -ge) if 3 parameters passed.
# @param 3 (opt) : Expected value actual value tested against using.
#                  binary operator.
REQUIRE_FALSE() {
  __sh_test_assert__ "REQUIRE_FALSE" true "$@"
}

# @brief Expect condition to be false.
#
# Test the passed expression, update the test and assert counts as appropriate.
# Failure if expression true.
#
# Call forms:
#
# CHECK_FALSE ${actualboolvalue}
# CHECK_FALSE uo ${actualvalue}
# CHECK_FALSE ${actualvalue} bo ${expectedvalue}
#
# where:
#  uo is a unary operator such as -z or -n
#  bo is a binary operator such as = or -lt
#
# @param 1       : A true/false value if only 1 parameter passed.
#                  A unary test operator (e.g. -z) if 2 parameters passed.
#                  Actual test value if 3 parameters passed.
# @param 2 (opt) : Actual test value if 2 parameters passed.
#                  Binary test operator (e.g. -ge) if 3 parameters passed.
# @param 3 (opt) : Expected value actual value tested against using.
#                  binary operator.
CHECK_FALSE() {
  __sh_test_assert__ "CHECK_FALSE" true "$@"
}

# @brief Expect string to contain all of number of sub strings.
#
# Test the passed strings in parameters 2+ are all in the string passed as
# parameter 1, update the test and assert counts as appropriate. Test fails
# if not all string in parameters 2+ are substrings of parameter 1.
#
# Call form:
#
# CHECK_CONTAINS_ALL ${actualstring} ${containedsubstring} ...
#
# @param 1  : String to test for contained substrings.
# @param 2+ : One or more substrings expected to be contained in param 1.
CHECK_CONTAINS_ALL() {
  __sh_test_assert_contains_all__ "CHECK_CONTAINS_ALL" false "$@"
}

# @brief Require string to contain all of number of sub strings, exit if not
#
# Test the passed strings in parameters 2+ are all in the string passed as
# parameter 1, update the test and assert counts as appropriate, and if not
# print the test count values and exit with a return code of 1. 
#
# Call form:
#
# REQUIRE_CONTAINS_ALL ${actualstring} ${containedsubstring} ...
#
# @param 1  : String to test for contained substrings.
# @param 2+ : One or more substrings required to be contained in param 1.
REQUIRE_CONTAINS_ALL() {
  __sh_test_assert_contains_all__ "REQUIRE_CONTAINS_ALL" true "$@"
}

# @brief Invoke function as test.
#
# Performs test book keeping around test function invocation. The test
# function name is passed as string as first parameter. The  test function
# is passed no arguments and no returned value is expected.
#
# @param 1  : Name of test function.
TEST() {
  if ${__sh_test_is_uninitialised__}; then
    __sh_test_set_flags__ ${__sh_test_command_line_arguments__}
    __sh_test_is_uninitialised__=false
  fi
  local prev_test="${__sh_test_testfn__}"
  local initial_failed_assertions=${__sh_test_asserts_failed__}
  __sh_test_testfn__="${1}"
  if ${__sh_test_flag_test_elapsed_times}; then
    local start_seconds="$(date +%s.%N)"
  fi
  "${__sh_test_testfn__}"
  if ${__sh_test_flag_test_elapsed_times}; then
    local end_seconds="$(date +%s.%N)"
    # This long winded way to try to subtract one floating point value
    # from another tries to allow for system that do _not_ porvied the
    # POSIX bc utility but might provide the dc utility...
    elapsed_time="\
$( printf '%s\n' "${end_seconds} - ${start_seconds}" | bc -q 2>/dev/null \
|| printf '%s\n' "${end_seconds} ${start_seconds} - p" | dc  \
)"
    printf '%s\n' "ELAPSED TIME: ${elapsed_time} seconds : ${__sh_test_testfn__}"
    # This long winded way to try to add 2 floating point values
    # tries to allow for system that do _not_ porvied the POSIX bc utility
    # but might provide the dc utility...
    __sh_test_total_time_secs__="\
$( printf '%s\n' "${__sh_test_total_time_secs__} + ${elapsed_time}" | bc -q 2>/dev/null \
|| printf '%s\n' "${__sh_test_total_time_secs__} ${elapsed_time} + p" | dc  \
)"
  fi
  __sh_test_testfn__="${prev_test}"
  if [ ${__sh_test_asserts_failed__} -gt ${initial_failed_assertions} ]; then
    __sh_test_update_failed__
  else
    __sh_test_update_passed__
  fi
}

# @brief Print accumulated test counts to stdout.
#
# Should be called after all test executions.
PRINT_TEST_COUNTS() {
  local timing_phrase=''
  if ${__sh_test_flag_test_elapsed_times}; then
    local timing_phrase=" in ${__sh_test_total_time_secs__} seconds"
  fi

  cat << EOF
Performed \
${__sh_test_tests__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_tests__}) / \
${__sh_test_asserts__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts__}). \
Passed ${__sh_test_passed__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_passed__}) / \
${__sh_test_asserts_passed__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts_passed__}). \
Failed ${__sh_test_failed__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_failed__}) / \
${__sh_test_asserts_failed__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts_failed__})\
${timing_phrase}.
EOF
}

# Details 

__sh_test_command_line_arguments__="$@"
__sh_test_flag_report_always__=false
__sh_test_flag_test_elapsed_times=false
__sh_test_flag_help__=false
__sh_test_flag_version__=false
__sh_test_is_uninitialised__=true
__sh_test_testfn__="__main__"
__sh_test_passed__=0
__sh_test_failed__=0
__sh_test_tests__=0
__sh_test_asserts_passed__=0
__sh_test_asserts_failed__=0
__sh_test_asserts__=0
__sh_test_total_time_secs__=0.0

__sh_test_print_report__() {
  local test_result="${1}"
  local test_variant="${2}"
  local test_expression="${3}"
  local test_state="FAILURE"

  if ${test_result}; then 
    local test_state="SUCCESS"
  fi
  printf '%s\n' "${test_state}: ${__sh_test_testfn__} ${test_variant} ${test_expression} is ${test_result}."
}

__sh_test_update_passed__() {
  __sh_test_passed__=$(( ${__sh_test_passed__} + 1 ))
  __sh_test_tests__=$(( ${__sh_test_tests__} + 1 ))
}

__sh_test_update_failed__() {
  __sh_test_failed__=$(( ${__sh_test_failed__} + 1 ))
  __sh_test_tests__=$(( ${__sh_test_tests__} + 1 ))
}

__sh_test_update_assert_passed__() {
  local test_variant="${1}"
  local test_expression="${2}"
  __sh_test_asserts_passed__=$(( ${__sh_test_asserts_passed__} + 1 ))
  __sh_test_asserts__=$(( ${__sh_test_asserts__} + 1 ))
  if ${__sh_test_flag_report_always__}; then
    __sh_test_print_report__ "true" "${test_variant}" "${test_expression}"
  fi
}

__sh_test_update_assert_failed__() {
  local test_variant="${1}"
  local test_expression="${2}"
  __sh_test_asserts_failed__=$(( ${__sh_test_asserts_failed__} + 1 ))
  __sh_test_asserts__=$(( ${__sh_test_asserts__} + 1 ))
  __sh_test_print_report__ "false" "${test_variant}" "${test_expression}"
}

__sh_test_maybe_plural__() {
  if [ ${2} -eq 1 ]; then
    printf '%s\n' "${1}"
  else
    printf '%s\n' "${1}s"
  fi
}

__sh_test_assert__() {
  local test_variant="${1}"
  local invert="${2}"
  shift 2
  if [ $# = 1 ]; then
    result="${1}"
  elif [ $# = 2 ]; then
    local test="${1}"
    local actual="${2}"
    local expression="${test} \"${actual}\""
    if [ "${test}" "${actual}" ]; then
      local result=true
    else
      local result=false
    fi
    local expected=''
  elif [ $# -ge 3 ]; then
    local actual="${1}"
    local test="${2}"
    local expected="${3}"
    local expression="\"${actual}\" ${test} \"${expected}\""
    if [ "${actual}" ${test} "${expected}" ]; then
      local result=true
    else
      local result=false
    fi
    if [ $# -gt 3 ]; then
      printf '%s\n' "WARNING: ${test_variant} passed too many arguments: need 1, 2 or 3, $# provided. Extra ignored." >&2
    fi
  else
    printf '%s\n' "ERROR: ${test_variant} passed too few arguments: need 1, 2 or 3, $# provided." >&2
    local result=false
    test_variant="REQUIRE"
  fi

  if ${invert}; then
    if ${result}; then
      result=false
    else
      result=true
    fi
  fi
  if ${result}; then
    __sh_test_update_assert_passed__ "${test_variant}" "${expression}"
  else
    __sh_test_update_assert_failed__ "${test_variant}" "${expression}"
    if [ "${test_variant}" = "REQUIRE" ] || [ "${test_variant}" = "REQUIRE_FALSE" ]; then
      PRINT_TEST_COUNTS
      exit 1
    fi
  fi
}

__sh_test_contains_all__() {
  local test_str="${1}"
  shift
  if [ "$#" -gt "0" ] && [ -z "${test_str}" ]; then
    false; return
  fi
  local empty_if_contains=""
  while [ "$#" -gt "0" ]; do
    empty_if_contains="${test_str%%*${1}*}"
    if [ -n "${empty_if_contains}" ]; then
      false; return
    fi
    shift
  done
  true; return
}

__sh_test_assert_contains_all__() {
  local test_variant="${1}"
  local invert="${2}"
  shift 2
  local expression="$*"
  __sh_test_contains_all__ "$@"
  if [ $? -eq 0 ]; then
    __sh_test_update_assert_passed__ "${test_variant}" "${expression}"
  else
    __sh_test_update_assert_failed__ "${test_variant}" "${expression}"
    if [ "${test_variant}" = "REQUIRE_CONTAINS_ALL" ] ; then
      PRINT_TEST_COUNTS
      exit 1
    fi
  fi
}
__sh_test_print_help__() {
  cat << EOF
Usage
${0} [OPTIONS]

-s, --success     Report successful as well as failed assertions.
-t, --timings     Report (rough) elapsed timings.
-h, --help        Print this help and exit.
-v, --version     Print sh-test version and exit.
EOF
}

__sh_test_print_version__() {
  cat << EOF
sh-test 0.1
Copyright © 2022 Ralph E. McArdell.
EOF
}

__sh_test_set_flags_shift_by__=0
__sh_test_process_long_commandline_arg__() {
#    printf '%s\n' "Processing option ${1}..." >&2
  local consumedArgs=1
  case ${1} in
    --help)
      __sh_test_flag_help__=true
      ;;
    --version)
      __sh_test_flag_version__=true
      ;;
    --success)
      __sh_test_flag_report_always__=true
      ;;
    --timings)
      __sh_test_flag_test_elapsed_times=true
      ;;
    *)
      consumedArgs=0
      ;;
  esac
  __sh_test_set_flags_shift_by__="${consumedArgs}"
}

__sh_test_set_flags__() {
  local shift_by=0
  while getopts ":hvst" arg; do
    case ${arg} in
      h)
        __sh_test_process_long_commandline_arg__ --help
        ;;
      v)
        __sh_test_process_long_commandline_arg__ --version
        ;;
      s)
        __sh_test_process_long_commandline_arg__ --success
        ;;
      t)
        __sh_test_process_long_commandline_arg__ --timings
        ;;
      *)
        shift $((OPTIND-2))
        __sh_test_process_long_commandline_arg__ $@
        if [ ${__sh_test_set_flags_shift_by__} = '0' ]; then
          printf '%s\n' "Sorry I do not understand command line argument '${1}'. Quitting." >&2
          exit 1
        fi
        shift
        OPTIND=1
        ;;
    esac
  done
  if ${__sh_test_flag_help__}; then
    __sh_test_print_help__
    exit 0
  fi
  if ${__sh_test_flag_version__}; then
    __sh_test_print_version__
    exit 0
  fi
  return
}

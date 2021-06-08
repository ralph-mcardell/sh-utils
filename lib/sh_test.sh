#!/bin/sh
#
# Mini unit testing framework for sh (sh not bash) script 'units' - functions
#

REQUIRE() {
  __sh_test_assert__ "REQUIRE" false "$@"
}

CHECK() {
  __sh_test_assert__ "CHECK" false "$@"
}

REQUIRE_FALSE() {
  __sh_test_assert__ "REQUIRE_FALSE" true "$@"
}

CHECK_FALSE() {
  __sh_test_assert__ "CHECK_FALSE" true "$@"
}

CHECK_CONTAINS_ALL() {
  __sh_test_assert_contains_all__ "CHECK_CONTAINS_ALL" false "$@"
}

REQUIRE_CONTAINS_ALL() {
  __sh_test_assert_contains_all__ "REQUIRE_CONTAINS_ALL" true "$@"
}

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
    elapsed_time="$( echo "${end_seconds} - ${start_seconds}" | bc -q)"
    echo "ELAPSED TIME: ${elapsed_time} seconds : ${__sh_test_testfn__}"
    __sh_test_total_time_secs__="$( echo "${__sh_test_total_time_secs__} + ${elapsed_time}" | bc -q)"
  fi
  __sh_test_testfn__="${prev_testfn}"
  if [ ${__sh_test_asserts_failed__} -gt ${initial_failed_assertions} ]; then
    __sh_test_update_failed__
  else
    __sh_test_update_passed__
  fi
}

PRINT_TEST_COUNTS() {
  local timing_phrase=''
  if ${__sh_test_flag_test_elapsed_times}; then
    local timing_phrase=" in ${__sh_test_total_time_secs__} seconds."
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
  echo "${test_state}: ${__sh_test_testfn__} ${test_variant} ${test_expression} is ${test_result}."
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
    echo "${1}"
  else
    echo "${1}s"
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
      echo "WARNING: ${test_variant} passed too many arguments: need 2 or 3, $# provided. Extra ignored." >&2
    fi
  else
    echo "ERROR: ${test_variant} passed too few arguments: need 1, 2 or 3, $# provided." >&2
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
Copyright © 2021 Ralph E. McArdell.
EOF
}

__sh_test_set_flags_shift_by__=0
__sh_test_process_long_commandline_arg__() {
#    echo "Processing option ${1}..." >&2
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
          echo "Sorry I do not understand command line argument '${1}'. Quitting." >&2
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

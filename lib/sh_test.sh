#!/bin/sh
#
# Mini unit testing framework for sh (sh not bash) script 'units' - functions
#
__sh_test_flag_report_always__=false
__sh_test_testfn__="__main__"
__sh_test_passed__=0
__sh_test_failed__=0
__sh_test_tests__=0
__sh_test_asserts_passed__=0
__sh_test_asserts_failed__=0
__sh_test_asserts__=0

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

TEST() {
  local prev_test="${__sh_test_testfn__}"
  local initial_failed_assertions=${__sh_test_asserts_failed__}
  __sh_test_testfn__="${1}"
  ${__sh_test_testfn__}
  __sh_test_testfn__="${prev_testfn}"
  if [ ${__sh_test_asserts_failed__} -gt ${initial_failed_assertions} ]; then
    __sh_test_update_failed__
  else
    __sh_test_update_passed__
  fi
}


PRINT_TEST_COUNTS() {
  cat << EOF
Performed \
${__sh_test_tests__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_tests__}) / \
${__sh_test_asserts__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts__}). \
Passed ${__sh_test_passed__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_passed__}) / \
${__sh_test_asserts_passed__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts_passed__}). \
Failed ${__sh_test_failed__} $(__sh_test_maybe_plural__ 'test' ${__sh_test_failed__}) / \
${__sh_test_asserts_failed__} $(__sh_test_maybe_plural__ 'assertion' ${__sh_test_asserts_failed__}).
EOF
}

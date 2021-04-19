#!/bin/sh

# Associative array (aka DICTionary) functions.
#
# Allows string values to be associated with a string keys.
#
# Strings can contain any printable ASCII or UTF-8 encoded characters
# as well as most unprintable characters except ASCII FS, GS, RS and US.
# These are reserved for dict implementation purposes.
#
# Values can also be other dict (formatted strings), that is dicts can be
# nested in dicts.
#
# As hinted above the implementation is a specially formatted string which
# uses ASCII separator control code values to separate key from value within
# an entry and entries from each other. Entries are stored in the order they
# are added so dicts are unsorted. As manipulation requries string pattern
# matching, cutting, pasting and (for nesting / unnesting) subsitution via
# sed do not expect anything like decent performance. On the other hand they
# are just strings so are naturally serialised and can be saved and restoed
# to files or sent and recieved over character streams (network, serial etc.)
#
# Use:
# dict_declare        to declare a dict variable, optionally initialised
# dict_declare_simple with initial key, value entries. Returns the dict
#                     value that can be associated with a variable.
# dict_set            to add or update a key,value to a previously
# dict_set_simple     dict_declare'd variable. Returns the updated dict.
#
# dict_get            to retrieve a value associated with a key in a
# dict_set_simple     previously dict_declare'd variable. Return the value
#                     if passed key present or blank if it is not.
# dict_remove         to remove a key,value entry from a dict. Returns the
#                     updated dict.
# dict_is_dict        to see if a variable's value represents a dict type.
# dict_for_each       to iterate over the entries of a dict, having
#                     a function called for each key value pair.
# dict_to_vars        to convert each key in a dict to a variable having
#                     the name of the key's value, and value of the key's
#                     associated value.
# dict_print_raw      to print the raw string of a dict variable with
#                     substitutions for the US, RS, GS and FS non-printing
#                     separator characters. Useful for debugging and similar.
#
# '_simple' suffixed functions are simpler versions that do not support
# nesting of dict values in other dict variables. They should have less
# overhead as nested dicts have to have their field and record separator
# sequences modified on insertion in a dict and restored when retrieved.
#-------------------------------------------------------------------------------

# @brief return true if first parameter appears to be a dict
#
# Specifically looks for the special __DICT_TYPE_VALUE__ string
# as a first dict-style record in the string.
#
# @param 1 : value or variable to query
# @returns : true if "${1}" appears to be a dict - that is adheres to the dict
#            string format, false otherwise.
dict_is_dict() {
    if [ "${1%%${__DICT_ENTRY_SEPARATOR__}*}X" = "${__DICT_TYPE_VALUE__}X" ]; then
        true; return
    else
        false; return
    fi
}

# @brief 'declare' a dict variable, optionally initialiing with entries
#
# Returns a value for storage in a variable that adheres to the dict
# string format. If provided each pair of parameters are used to
# add key value entries to the returned dict value. For each such pair
# BOTH the key and value cannot be another dict, and cannot contain
# ASCII US, RS, GS, FS characters.
#
# @param 2n-1 : entry n key value. n > 0.
# @param 2n   : entry n value value. n > 0.
# @returns : dict value containing 0+ entries that can be used with the
#            other dict_xxx functions and for which specifically when
#            passed to dict_is_dict returns true.
dict_declare_simple() {
    local dict="${__DICT_TYPE_RECORD__}"
    while [ $# -gt 1 ]; do
        local dkey="$(__dict_decorated_key__ "${1}")"
        local value="${2}"
        dict="${dict}$(__dict_new_entry__ "${dkey}" "${value}")"
        shift 2
    done
    if [ $# -gt 0 ]; then
        echo "WARNING: incomplete key, value pair passed to dict_declare: ${1} left over." >&2
    fi
    cat << EOF
${dict}
EOF
}

# @brief Set - add or update - a key, value entry in a dict
#
# Passed a dict to update, a key and a value.
# Returns the updated dict value.
#
# BOTH the key and value cannot be another dict, and cannot contain
# ASCII US, RS, GS, FS characters.
#
# If there is no entry in the passed dict having a key value matching
# matching the passed key a new entry is appended to the dict value returned.
#
# Otherwise the value of the existing entry in the passed dict having a key
# value matching that of the passed key is updated to the new value.
#
# @param 1 : dict value to set value in
# @param 2 : Entry key value.
# @param 3 : Entry value value.
# @returns : dict value containing the updated or added (appended)
#            entry.
dict_set_simple() {
    __dict_abort_if_not_dict__ "${1}" "dict_set_simple"
    __dict_set__ "$@"
}


# @brief Get a value associated with a key from a dict
#
# Passed a dict to query and a key.
# Returns the value associated with the key or blank if the 
# passed dict contains no entry having a matching key.
#
# BOTH the passed key and any returned value cannot be another dict,
# and cannot contain ASCII US, RS, GS, FS characters.
#
# @param 1 : dict value to set value in
# @param 2 : Entry key value.
# @returns : value of entry in dict passed as parameter 1 having key
#            matching parameter 2 or blank (empty) value.
dict_get_simple() {
    __dict_abort_if_not_dict__ "${1}" "dict_get_simple"
    __dict_get__ "$@"
}

# @brief 'declare' a dict variable, optionally initialiing with entries
#
# Returns a value for storage in a variable that adheres to the dict
# string format. If provided each pair of parameters are used to
# add key value entries to the returned dict value. For each such pair:
#   - The key cannot be another dict, and cannot contain ASCII
#     US, RS, GS, FS characters.
#
#   - The value maybe another dict but otherwise cannot contain
#     ASCII US, RS, GS, FS characters. #
# @param 2n-1 : entry n key value. n > 0.
# @param 2n   : entry n value value. n > 0.
# @returns : dict value containing 0+ entries that can be used with the
#            other dict_xxx functions and for which specifically when
#            passed to dict_is_dict returns true.
dict_declare() {
    local dict="${__DICT_TYPE_RECORD__}"
    while [ $# -gt 1 ]; do
        local dkey="$(__dict_decorated_key__ "${1}")"
        local value="${2}"
        if dict_is_dict "${value}"; then
            local value="$(__dict_prepare_value_for_nesting__ "${value}")"
        fi
        dict="${dict}$(__dict_new_entry__ "${dkey}" "${value}")"
        shift 2
    done
    if [ $# -gt 0 ]; then
        echo "WARNING: incomplete key, value pair passed to dict_declare: ${1} left over." >&2
    fi
    cat << EOF
${dict}
EOF
}

# @brief Set - add or update - a key, value entry in a dict
#
# Passed a dict to update, a key and a value.
# Returns the updated dict value.
#
# The key cannot be another dict, and cannot contain ASCII
# US, RS, GS, FS characters.
#
# The value maybe another dict but otherwise cannot contain
# ASCII US, RS, GS, FS characters. 
#
# If there is no entry in the passed dict having a key value matching
# matching the passed key a new entry is appended to the dict value returned.
#
# Otherwise the value of the existing entry in the passed dict having a key
# value matching that of the passed key is updated to the new value.
#
# @param 1 : dict value to set value in
# @param 2 : Entry key value.
# @param 3 : Entry value value.
# @returns : dict value containing the updated or added (appended)
#            entry.
dict_set() {
    __dict_abort_if_not_dict__ "${1}" "dict_set"
    local value="${3}"
    if dict_is_dict "${value}"; then
        local value="$(__dict_prepare_value_for_nesting__ "${value}")"
    fi
    cat << EOF
$(__dict_set__ "${1}" "${2}" "${value}")
EOF
}

# @brief Get a value associated with a key from a dict
#
# Passed a dict to query and a key.
# Returns the value associated with the key or blank if the 
# passed dict contains no entry having a matching key.
#
# The key cannot be another dict, and cannot contain ASCII
# US, RS, GS, FS characters.
#
# The value of the entry to remove maybe another dict.
#
#
# @param 1 : dict value to set value in
# @param 2 : Entry key value.
# @returns : value of entry in dict passed as parameter 1 having key
#            matching parameter 2 or blank (empty) value.
dict_get() {
    __dict_abort_if_not_dict__ "${1}" "dict_get"
    local value="$(__dict_get__ "$@")"
    if __dict_is_nested_dict__ "${value}"; then
        cat << EOF
$(__dict_prepare_value_for_unnesting__ "${value}")
EOF
    else
        cat << EOF
${value}
EOF
    fi
}

# @brief Remove an entry having a matching key form a dict
#
# Passed a dict to update, and the key of the entry to remove.
#
# The key cannot be another dict, and cannot contain ASCII
# US, RS, GS, FS characters.
#
# The value maybe another dict but otherwise cannot contain
# ASCII US, RS, GS, FS characters. 
#
# Returned the possibly updated dict. The returned dict
# value with match the passed dict value if there is no
# entry with a matching key.
#
# @param 1 : dict value to remove a value from
# @param 2 : Key of entry to remove
# @returns : a value either matching the passed dict or the
#            passed dict with the requested entry removed.
dict_remove() {
    __dict_abort_if_not_dict__ "${1}" "dict_remove"
    local dict="$(__dict_strip_header__ "${1}" "false")"
    local dkey="$(__dict_decorated_key__ "${2}")"
    cat << EOF
${__DICT_TYPE_RECORD__}$(__dict_prefix_entries__ "${dict}" "${dkey}")$(__dict_suffix_entries__ "${dict}" "${dkey}")
EOF
}

# @brief Output the raw characters of the dict
#
# Passed a dict will output to the (sub-)shell stdout (i.e. return) the
# characters (bytes) making up the string representation og the dict with the 
# unprintable characters used in field and record separators (i.e. ASCI US RS
# GS and FS) translated to somethingprintable (usually) .
#
# The function optionally takes 2nd argument specifying the characters to
# translate US RS GS and FS characters (in that order) to. If not provided
# the translated to characters default to '_^]\'
#
# @param 1 : dict value to output
# @param 2 : (optional) characters to translate ASCII US RS GS FS characters
#            embedded in dict
# @returns : raw characters of dict with the US RS GS FS characters translated.
dict_print_raw() {
  local dict="${1}"
  local us_rs_gs_fs_translation='_^]\\'
  if [ $# -ge 2 ]; then
    us_rs_gs_fs_translation="${2}"
  fi
  echo "${dict}" | tr "${__DICT_US__}${__DICT_RS__}${__DICT_GS__}${__DICT_FS__}" "${us_rs_gs_fs_translation}" 
}

# @brief Iterate over dict calling a function taking each key value
#
# Iterate over the entries in the passed dict and call the function
# whose name is passed as the 2nd parameter passing it the key and value
# of each entry followed by any extra parameters passed to dict_for_each
# (parameter 3 onwards).
#
# @param 1 : dict value to iterate over
# @param 2 : name of function to call with each key, valaue and any
#            additional parameters passed to dict_for_each
# @param 3+: (optional) additional parameters passed as parameters 3+ to
#            the function named in param 2.
# @returns nothing
dict_for_each() {
    __dict_abort_if_not_dict__ "${1}" "dict_for_each"
    local dict="$(__dict_strip_header__ "${1}" "true")"
    local binaryFn="${2}"
    shift 2
    while [ -n "${dict}" ]; do
        local record="${dict%%${__DICT_ENTRY_SEPARATOR__}*}"
        local key="${record%${__DICT_FIELD_SEPARATOR__}*}"
        local value="${record#*${__DICT_FIELD_SEPARATOR__}}"
        local dict="${dict#*${__DICT_ENTRY_SEPARATOR__}}"
    #    echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${__DICT_RS__}${DICT___DICT_US__}" '^_' >&2
        ${binaryFn} "${key}" "${value}" "$@"
    done
}

# @brief Create a variable for each entry in a dict
# 
# For each entry a variable with the same name as the entry key and a
# value of the entry value is created.
#
# Do not execute in subshell to calling context as created
# variables will then not be available to calling context.
#
# @param 1 : dict value create variables from
dict_to_vars() {
    __dict_abort_if_not_dict__ "${1}" "dict_to_vars"
    local dict="$(__dict_strip_header__ "${1}" "true")"
    while [ -n "${dict}" ]; do
        local record="${dict%%${__DICT_ENTRY_SEPARATOR__}*}"
        local key="${record%${__DICT_FIELD_SEPARATOR__}*}"
        local value="${record#*${__DICT_FIELD_SEPARATOR__}}"
        local dict="${dict#*${__DICT_ENTRY_SEPARATOR__}}"
    #    echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${__DICT_RS__}${DICT___DICT_US__}" '^_' >&2
        read ${key} << EOF 
${value}
EOF
    done
}

# Details

__DICT_FS__=$(echo '@' | tr '@' '\034')
__DICT_GS__=$(echo '@' | tr '@' '\035')
__DICT_RS__=$(echo '@' | tr '@' '\036')
__DICT_US__=$(echo '@' | tr '@' '\037')

__DICT_RECORD_SEPARATOR__="${__DICT_RS__}"
__DICT_FIELD_SEPARATOR__="${__DICT_US__}"
__DICT_NESTING_PREFIX__="${__DICT_GS__}"

__DICT_ENTRY_SEPARATOR__="${__DICT_FIELD_SEPARATOR__}${__DICT_RECORD_SEPARATOR__}"
__DICT_TYPE_VALUE__="${__DICT_GS__}DiCt${__DICT_GS__}"
__DICT_TYPE_RECORD__="${__DICT_TYPE_VALUE__}${__DICT_ENTRY_SEPARATOR__}"

__dict_decorated_key__() {
    cat << EOF 
${1}${__DICT_FIELD_SEPARATOR__}
EOF
}

__dict_new_entry__() {
    local decorated_key="${1}"
    local value="${2}"
    cat << EOF 
${decorated_key}${value}${__DICT_ENTRY_SEPARATOR__}
EOF
}

__dict_prefix_entries__() {
    local dict="${1}"
    local decorated_key="${2}"
  # Must match on key prefixed by entry separator and terminated by field
  # seprarator to prevent key-strings in values looking like keys
  # However if we are not appending (in which case whole dict string is
  # value of prefix) then the entry separator removed by pattern match
  # removal has to be replaced by appending back onto the prefix string
    local prefix="${dict%${__DICT_ENTRY_SEPARATOR__}${decorated_key}*}"
    if [ "${prefix}" != "${dict}" ]; then
        local prefix="${prefix}${__DICT_ENTRY_SEPARATOR__}"
    fi
    cat << EOF
${prefix}
EOF
}

__dict_value_and_suffix_entries__() {
    local dict="${1}"
    local decorated_key="${2}"
    cat << EOF
${dict#*${__DICT_ENTRY_SEPARATOR__}${decorated_key}}
EOF
}

__dict_value__() {
    local dict="${1}"
    local decorated_key="${2}"
    local value_plus="$(__dict_value_and_suffix_entries__ "${dict}" "${decorated_key}")"
    if [ "${value_plus}" != "${dict}" ]; then
        cat << EOF
${value_plus%%${__DICT_ENTRY_SEPARATOR__}*}
EOF
    fi
}

__dict_suffix_entries__() {
    local dict="${1}"
    local decorated_key="${2}"
    local value_plus="$(__dict_value_and_suffix_entries__ "${dict}" "${decorated_key}")"
    if [ "${value_plus}" != "${dict}" ]; then
        suffix_entries="${value_plus#*${__DICT_ENTRY_SEPARATOR__}}"
        if [ "${suffix_entries}" = "${value_plus}" ]; then
            suffix_entries=''
        fi
        cat << EOF
${suffix_entries}
EOF
    fi
}

__dict_strip_header__() {
    local dict="${1}"
    local all="${2}"
    if "${all}"; then
        local stripped="${__DICT_TYPE_RECORD__}"
    else
        local stripped="${__DICT_TYPE_VALUE__}"
    fi
    local entries="${dict#${stripped}}"
    if [ "${entries}" != "${dict}" ]; then
    cat << EOF
${entries}
EOF
    fi
}

__dict_prepare_value_for_nesting__() {
    local value="${1}"
    sed "s/${__DICT_US__}/${__DICT_GS__}${__DICT_US__}/g; s/${__DICT_RS__}/${__DICT_GS__}${__DICT_RS__}/g" << EOF
${value}
EOF
}

__dict_prepare_value_for_unnesting__() {
    local value="${1}"
    sed "s/${__DICT_GS__}${__DICT_US__}/${__DICT_US__}/g; s/${__DICT_GS__}${__DICT_RS__}/${__DICT_RS__}/g" << EOF
${value}
EOF
}

__dict_is_nested_dict__() {
    if [ "${1%%${__DICT_GS__}[!D${__DICT_GS__}]*}X" = "${__DICT_TYPE_VALUE__}X" ]; then
        true; return
    else
        false; return
    fi
}

__dict_abort_if_not_dict__() {
    if ! dict_is_dict "${1}"; then
        echo "Oops! First argument passed to ${2} is not a dict(ionary) type. Quitting current (sub-)shell." >&2
        exit 1
    fi
}

__dict_set__() {
    local dict="$(__dict_strip_header__ "${1}" "false")"
    local dkey="$(__dict_decorated_key__ "${2}")"
    local value="${3}"
    cat << EOF
${__DICT_TYPE_VALUE__}$(__dict_prefix_entries__ "${dict}" "${dkey}")$(__dict_new_entry__ "${dkey}" "${value}")$(__dict_suffix_entries__ "${dict}" "${dkey}")
EOF
}


__dict_get__() {
    local dict="$(__dict_strip_header__ "${1}" "false")"
    local dkey="$(__dict_decorated_key__ "${2}")"
    cat << EOF
$(__dict_value__ "${dict}" "${dkey}")
EOF
}

#!/bin/sh
# Copyright (c) 2021 Ralph. E. McArdell
# All rights reserved.
# Licensed under BSD 2-Clause License - see LICENSE.md for full text.
#
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
# Uses POSIX/Open Group IEEE Std 1003.1-2017 shell command language facilities
# plus utility local and commands tr, sed.
#
# As hinted above the implementation is a specially formatted string which
# uses ASCII separator control code values to separate key from value within
# an entry and entries from each other. Entries are stored in the order they
# are added so dicts are unsorted. As manipulation requries string pattern
# matching, cutting, pasting and (for nesting / unnesting) subsitution via
# sed do not expect anything like decent performance. On the other hand they
# are just strings so are naturally serialised and can be saved and restored
# to files or sent and received over character streams (network, serial etc.)
#
# Use:
# dict_declare        to declare a dict variable, optionally initialised
# dict_declare_simple with initial key, value entries. Returns the dict
#                     value that can be associated with a variable.
# dict_set            to add or update a key,value to a previously
# dict_set_simple     dict_declare'd variable. Returns the updated dict.
#
# dict_get            to retrieve a value associated with a key in a
# dict_get_simple     previously dict_declare'd variable. Return the value
#                     if passed key present or blank if it is not.
# dict_remove         to remove a key,value entry from a dict. Returns the
#                     updated dict.
# dict_is_dict        to see if a variable's value represents a dict type.
# dict_size           return the integer value of the size of the dict,
# dict_count          being the number of records. dict_size is ~O(1)
#                     whereas dict_count is ~O(n), hence dict_size is intended
#                     to be usually used over dict_count, which iterates
#                     over the entries in a dict and returnd the count of
#                     records itereted over.
# dict_for_each       to iterate over the entries of a dict, having
#                     a function called for each key value pair.
# dict_print_raw      to print the raw string of a dict variable with
#                     substitutions for the US, RS, GS and FS non-printing
#                     separator characters. Useful for debugging and similar.
# dict_pretty_print   output dict entries with customisable surrounding 
#                     decoration.
# '_simple' suffixed functions are simpler versions that do not support
# nesting of dict values in other dict variables. They should have less
# overhead as nested dicts have to have their field and record separator
# sequences modified on insertion in a dict and restored when retrieved.
#
# Use with dict_for_each:
#
# dict_op_to_var_flat to create variables with the value of dict entries'
#                     value and a name based on the dict entries' key value
#                     with optional prefix and/or suffix.
#-------------------------------------------------------------------------------

if [ -z ${__DICT_INCLUDED_20210604__} ];
then
  __DICT_INCLUDED_20210604__=yes
    # @brief return true if first parameter appears to be a dict
    #
    # Specifically looks for the special __DICT_TYPE_VALUE__ string
    # as a first dict-style record in the string.
    #
    # @param 1 : value or variable to query
    # @returns : true if "${1}" appears to be a dict - that is adheres to the dict
    #            string format, false otherwise.
    dict_is_dict() {
        if [ $# -ge 1 ] && \
        [ "${1%%${__DICT_ENTRY_SEPARATOR__}*}X" = "${__DICT_TYPE_VALUE__}X" ]; then
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
        local dict="${__DICT_DECL_HDR_RECORD__}"
        local keys=${__DICT_RS__}
        while [ $# -gt 1 ]; do
            __dict_decorated_key__ "${1}"
            if [ "${keys##${__DICT_RS__}*${__DICT_US__}${__dict_return_value__}}" != "${keys}" ]; then
                echo "ERROR: duplicate key \"${1}\" passed to dict_declare_simple." >&2
                echo ""
                exit 1
            fi
            local keys="${keys}${__DICT_US__}${__dict_return_value__}"
            local value="${2}"
            __dict_new_entry__ "${__dict_return_value__}" "${value}"
            dict="${dict}${__dict_return_value__}"
            __dict_add_to_size__ "${dict}" 1
            dict="${__dict_return_value__}"
            shift 2
        done
        if [ $# -gt 0 ]; then
            echo "WARNING: incomplete key, value pair passed to dict_declare_simple: ${1} left over." >&2
        fi
        echo -n "${dict}"
    }

    # @brief Set - add or update - a key, value entry in a dict
    #
    # Passed a dict to update, one or more key and value parameter pairs.
    # Returns the updated dict value.
    #
    # NO key or value can be another dict, and cannot contain
    # ASCII US, RS, GS, FS characters.
    #
    # If there is no entry in the passed dict having a key value matching
    # matching a passed key a new entry is appended to the dict value returned.
    #
    # Otherwise the value of the existing entry in the passed dict having a key
    # value matching that of a passed key is updated to the new associated
    # passed value.
    #
    # @param 1 : dict value to set value in
    # @param 2 : Entry key value.
    # @param 3 : Entry value value.
    # @param 4, 6, ... 4+2n : (optional) Additional key value
    # @param 5, 7, ... 5+2n : (optional) Additional value value
    # @returns : dict value containing the updated or added (appended)
    #            entries.
    dict_set_simple() {
        __dict_abort_if_not_dict__ "${1}" "dict_set_simple"
        __dict_return_value__="${1}"
        shift
        while [ $# -ge 2 ]; do
          __dict_set__ "${__dict_return_value__}" "${1}" "${2}"
          shift 2
        done
        echo -n "${__dict_return_value__}"
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
        echo -n "${__dict_return_value__}"
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
    # @returns : 0 and dict value containing 0+ entries that can be used with
    #            the other dict_xxx functions and for which specifically when
    #            passed to dict_is_dict returns true.
    #            1 (fail) and empty string if duplicate key values provided
    #            for param 2n-1 values.
    dict_declare() {
        local dict="${__DICT_DECL_HDR_RECORD__}"
        local keys=${__DICT_RS__}
        while [ $# -gt 1 ]; do
            __dict_decorated_key__ "${1}"
            if [ "${keys##${__DICT_RS__}*${__DICT_US__}${__dict_return_value__}}" != "${keys}" ]; then
                echo "ERROR: duplicate key \"${1}\" passed to dict_declare." >&2
                echo ""
                exit 1
            fi
            local dkey="${__dict_return_value__}"
            local keys="${keys}${__DICT_US__}${dkey}"
            local value="${2}"
            if dict_is_dict "${value}"; then
                __dict_prepare_value_for_nesting__ "${value}"
                value="${__dict_return_value__}"
            fi
            __dict_new_entry__ "${dkey}" "${value}"
            dict="${dict}${__dict_return_value__}"
            __dict_add_to_size__ "${dict}" 1
            dict="${__dict_return_value__}"
            shift 2
        done
        if [ $# -gt 0 ]; then
            echo "WARNING: incomplete key, value pair passed to dict_declare: ${1} left over." >&2
        fi
#echo "@@ @@ dict_declare dict: '$(dict_print_raw "${dict}")'" >&2        
        echo -n "${dict}"
    }

    # @brief Set - add or update - a key, value entry in a dict
    #
    # Passed a dict to update, one or more key and value parameter pairs.
    # Returns the updated dict value.
    #
    # A key cannot be another dict, and cannot contain ASCII
    # US, RS, GS, FS characters.
    #
    # Values maybe another dict but otherwise cannot contain
    # ASCII US, RS, GS, FS characters.
    #
    # If there is no entry in the passed dict having a key value matching
    # a passed key a new entry is appended to the dict value returned.
    #
    # Otherwise values of existing entries in the passed dict having a key
    # value matching that of a passed key are updated to the new associated
    # passed value.
    #
    # @param 1 : dict value to set value in
    # @param 2 : Entry key value.
    # @param 3 : Entry value value.
    # @param 4, 6, ... 4+2n : (optional) Additional key value
    # @param 5, 7, ... 5+2n : (optional) Additional value value
    #
    # @returns : dict value containing the updated or added (appended)
    #            entry.
    dict_set() {
        __dict_abort_if_not_dict__ "${1}" "dict_set"
        local dict="${1}"
        shift
        while [ $# -ge 2 ]; do
            local value="${2}"
            if dict_is_dict "${value}"; then
                __dict_prepare_value_for_nesting__ "${value}"
                value="${__dict_return_value__}"
            fi
            __dict_set__ "${dict}" "${1}" "${value}"
            dict="${__dict_return_value__}"
            shift 2
        done
#echo "@@ @@     DICT_SET:    updated size: '$(dict_print_raw "${__dict_return_value__}")'" >&2
        echo -n "${__dict_return_value__}"
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
    # The value of the entry to retrieve maybe another dict.
    #
    # @param 1 : dict value to set value in
    # @param 2 : Entry key value.
    # @returns : value of entry in dict passed as parameter 1 having key
    #            matching parameter 2 or blank (empty) value.
    dict_get() {
        __dict_abort_if_not_dict__ "${1}" "dict_get"
        __dict_get__ "$@"
        local value="${__dict_return_value__}${__DICT_GS__}"
        value="${value%${__DICT_GS__}}"
        if __dict_is_nested_dict__ "${value}"; then
            __dict_prepare_value_for_unnesting__ "${value}"
            value="${__dict_return_value__}"
        fi
        echo -n "${value}"
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
#echo "@@ @@ dict_remove: dict passed to:'$(dict_print_raw "${1}")'" >&2
        __dict_strip_header__ "${1}" "false"
        local dict="${__dict_return_value__}"
#echo "@@ @@ dict_remove:  stripped dict:'$(dict_print_raw "${dict}")'" >&2
        __dict_decorated_key__ "${2}"
        local dkey="${__dict_return_value__}"
        __dict_prefix_entries__ "${dict}" "${dkey}"
        local prefix="${__dict_return_value__}"
#echo "@@ @@ dict_remove:         prefix:'$(dict_print_raw "${prefix}")'" >&2
        if [ "${prefix}" = "${dict}" ]; then
          echo -n "${1}"
        else
          __dict_get_size__ "${1}"
          local size=$(( ${__dict_return_value__}-1 ))
          __dict_suffix_entries__ "${dict}" "${dkey}"
          local suffix="${__dict_return_value__}"
#echo "@@ @@ dict_remove:         suffix:'$(dict_print_raw "${suffix}")'" >&2
          dict="${__DICT_HDR_ENTRY_BASE__}${size}${prefix}${suffix}"
          echo -n "${dict}"
        fi
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
        __dict_strip_header__ "${1}" "true"
        local dict="${__dict_return_value__}"
        local binaryFn="${2}"
        shift 2
        local record_number=1
        while [ -n "${dict}" ]; do
            local record="${dict%%${__DICT_ENTRY_SEPARATOR__}*}"
            local key="${record%%${__DICT_FIELD_SEPARATOR__}*}"
            local value="${record#*${__DICT_FIELD_SEPARATOR__}}"
            local dict="${dict#*${__DICT_ENTRY_SEPARATOR__}}"
            if __dict_is_nested_dict__ "${value}"; then
                __dict_prepare_value_for_unnesting__ "${value}"
                value="${__dict_return_value__}"
            fi
        #    echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${__DICT_GS__}${__DICT_RS__}${__DICT_US__}" ']^_' >&2
            ${binaryFn} "${key}" "${value}" "${record_number}" "$@"
            record_number=$((${record_number}+1))
        done
    }

    # @brief Return number of entries in a dict
    #
    # Returns saved size of dict as updated on entry addition and removal.
    # Hence executes in ~O(1) 
    #
    # @param 1 : dict value to return size of
    # @returns size of dict: the number of key value entries in the dict
    dict_size() {
        __dict_abort_if_not_dict__ "${1}" "dict_size"
        __dict_get_size__ "${1}"
        echo -n "${__dict_return_value__}"
    }


    # @brief Return number of entries in a dict
    #
    # Iterate over the entries in the passed dict countig the number of
    # entries. Hence executes in ~O(n).
    #
    # Value returned by dict_size and dict_count should _always_ be the
    # same for the same dict input.
    #
    # @param 1 : dict value to return count of entries for
    # @returns count of key value entries in the dict
    dict_count() {
        __dict_abort_if_not_dict__ "${1}" "dict_count"
        dict_for_each "${1}" "__dict_op_recnums__"
        local size="${__dict_return_value__}"
        if [ -z "${size}" ]; then
            size="0"
        fi
        echo -n "${size}"
    }

    # @brief Output the raw characters of the dict
    #
    # Passed a dict will output to the (sub-)shell stdout (i.e. return) the
    # characters (bytes) making up the string representation og the dict with the
    # unprintable characters used in field and record separators (i.e. ASCI US RS
    # GS and FS) translated to something printable (usually) .
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

    # @brief Output the entries of a dict with user-defined decoration
    #
    # The key, value entries of the passed dict will be output to the
    # (sub-) shell stdout, with customisable decoration surrounding elements
    # of the  data output provided by a second print specification dict
    # passed as the second parameter.
    #
    # Will recursively print the entries of nested dict values.
    #
    # The print specification provides any or none of the following
    # string values to control the format of the output. Any value
    # not provided will be output as an empty string, hence providing
    # and empty print specification dict will just output each key,value
    # in order, including nested key values, with no separation between
    # each key and value or between each key, value entry.
    #
    # The available print specification keys and the use of their associated
    # values are:
    # 'print_prefix'      Characters output before any other dict output
    # 'print_suffix'      Characters output after all other dict output
    # 'nesting_indent'    Characters output after newlines for nested dict output;
    #                     applied to existing indent on each subsequent nesting.
    # 'nesting_prefix'    Characters output before any other nested dict output
    # 'nesting_suffix'    Characters output after all other nested dict output
    # 'dict_prefix'       Characters output before any dict entry output
    # 'dict_suffix'       Characters output after all dict entry output
    # 'record_separator'  Characters output between 'record_prefix' and
    #                     'record_suffix' characters. Useful for producing
    #                     list separators without trailing separator.
    # 'record_prefix'     Characters output before each dict entry output
    # 'record_suffix'     Characters output after each dict entry output
    # 'key_prefix'        Characters output before each dict entry key output
    # 'key_suffix'        Characters output after each dict entry key output
    # 'value_prefix'      Characters output before each dict entry value output
    # 'value_suffix'      Characters output after each dict entry value output
    #
    # As implied in the description of the value for the 'nesting_indent' key
    # print specification string values may contain newlines.
    #
    # @param 1 : dict to output
    # @param 2 : output print specification of decoration to output around dict
    #            key, value entries.
    # @returns: (to stdout of (sub-)shell) 'pretty-printed' representation of dict
    # @error: either parameter is not a dict. exit 1 from (sub-)shell.
    dict_pretty_print() {
    local dict="${1}"
    local pprint_specs="${2}"
    __dict_abort_if_not_dict__ "${1}" "dict_pretty_print"
    if ! dict_is_dict "${pprint_specs}"; then
        echo "Oops! Print specifications argument #2 passed to dict_pretty_print is not a dict(ionary) type. Quitting current (sub-)shell." >&2
        exit 1
    fi
    dict_get_simple "${pprint_specs}" "print_prefix"
    __dict_pretty_print__ "${dict}" "${pprint_specs}"
    dict_get_simple "${pprint_specs}" "print_suffix"
    }

    # @brief Create variable from key, value
    #
    # Operation function for use with dict_for_each.
    #
    # Will create a variable having the value of value passed as the
    # 2nd parameter and a name based on the key-value passed as the
    # 1st parameter.
    #
    # The variable created will be in the global scope of the (sub-)
    # shell of the call to dict_for_each.
    #
    # The name of the created variable in the simplest case is simply
    # the same as the key value. Optional prefix and suffix 3rd and
    # 4th parameters may be passed in which case the name of the
    # will be:
    #   ${prefix}${key}${suffiix} (that is ${3}${1}${4})
    # If the formed string is not a valid variable identifer bad
    # things will happen. To provided a suffix without a prefix specify
    # the prefix as a hyphen.
    #
    # If the value represents a nested dict then the value is unnested.
    #
    # Usage examples:
    #
    #  1/ simple: create variables matching key names of entries in dict
    #    dict_for_each "${dict}" dict_op_to_var_flat
    #
    #  2/ with prefix: create variables of the form 'dict_keyname'
    #    dict_for_each "${dict}" dict_op_to_var_flat 'dict_'
    #
    #  3/ with suffix: create variables of the form 'keyname_dict'
    #    dict_for_each "${dict}" dict_op_to_var_flat '-' '_dict'
    #
    #  4/ with prefix and suffix: create variables of the form 'dict_keyname_0'
    #    dict_for_each "${dict}" dict_op_to_var_flat 'dict_' '_0'
    #
    # @param 1 : key value
    # @param 2 : value value
    # @param 3 : (optional) variable name prefix or '-' for suffix only
    # @param 4 : (optional) variable name suffix
    dict_op_to_var_flat() {
        local var_name="${1}"
        local var_value="${2}"
        if [ $# -ge 4 ]; then
            if [ "${4}" != '-' ]; then
                local var_name="${4}${var_name}"
            fi
        fi
        if [ $# -ge 5 ]; then
            local var_name="${var_name}${5}"
        fi
        if __dict_is_nested_dict__ "${var_value}"; then
            __dict_prepare_value_for_unnesting__ "${var_value}"
            var_value="${__dict_return_value__}"
        fi
        read ${var_name} << EOF 
${var_value}
EOF
    }

    # Details

    __DICT_FS__=$(echo '@' | tr '@' '\034')
    __DICT_GS__=$(echo '@' | tr '@' '\035')
    __DICT_RS__=$(echo '@' | tr '@' '\036')
    __DICT_US__=$(echo '@' | tr '@' '\037')

    __DICT_RECORD_SEPARATOR__="${__DICT_RS__}"
    __DICT_FIELD_SEPARATOR__="${__DICT_US__}"
    __DICT_NESTING_PREFIX__="${__DICT_GS__}"

    __DICT_VERSION__='1.1.0'
    __DICT_ENTRY_SEPARATOR__="${__DICT_FIELD_SEPARATOR__}${__DICT_RECORD_SEPARATOR__}"
    __DICT_TYPE_VALUE__="${__DICT_GS__}DiCt${__DICT_GS__}"
    __DICT_HDR_ENTRY_BASE__="${__DICT_TYPE_VALUE__}${__DICT_ENTRY_SEPARATOR__}${__DICT_VERSION__}${__DICT_FIELD_SEPARATOR__}"
    __DICT_DECL_HDR_ENTRY__="${__DICT_HDR_ENTRY_BASE__}0"
    __DICT_DECL_HDR_RECORD__="${__DICT_DECL_HDR_ENTRY__}${__DICT_ENTRY_SEPARATOR__}"
    __DICT_PATN_HDR_RECORD__="${__DICT_HDR_ENTRY_BASE__}*${__DICT_ENTRY_SEPARATOR__}"
    __dict_return_value__=''

    __dict_decorated_key__() {
      __dict_return_value__="${1}${__DICT_FIELD_SEPARATOR__}"
    }

    __dict_new_entry__() {
        local decorated_key="${1}"
        local value="${2}"
        __dict_return_value__="${decorated_key}${value}${__DICT_ENTRY_SEPARATOR__}"
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
#echo "@@ @@ __dict_prefix_entries__: prefix splits dict: $(dict_print_raw "${prefix}")'" >&2
            prefix="${prefix}${__DICT_ENTRY_SEPARATOR__}"
        fi
        __dict_return_value__="${prefix}"
    }

    __dict_value_and_suffix_entries__() {
        local dict="${1}"
        local decorated_key="${2}"
        __dict_return_value__="${dict#*${__DICT_ENTRY_SEPARATOR__}${decorated_key}}"
    }

    __dict_value__() {
        local dict="${1}"
        local decorated_key="${2}"
        __dict_value_and_suffix_entries__ "${dict}" "${decorated_key}"
        local value_plus="${__dict_return_value__}"
        if [ "${value_plus}" != "${dict}" ]; then
            __dict_return_value__="${value_plus%%${__DICT_ENTRY_SEPARATOR__}*}"
        else
            __dict_return_value__=''
        fi
    }

    __dict_suffix_entries__() {
        local dict="${1}"
        local decorated_key="${2}"
        __dict_value_and_suffix_entries__ "${dict}" "${decorated_key}"
        local value_plus="${__dict_return_value__}"
        local suffix_entries=''
        if [ "${value_plus}" != "${dict}" ]; then
            suffix_entries="${value_plus#*${__DICT_ENTRY_SEPARATOR__}}"
            if [ "${suffix_entries}" = "${value_plus}" ]; then
                suffix_entries=''
            fi
        fi
        __dict_return_value__="${suffix_entries}"
    }

    __dict_strip_header__() {
        local dict="${1}"
#echo "@@ @@ dict passed to __dict_strip_header__:'$(dict_print_raw "${dict}")'" >&2
        local all="${2}"
        local stripped="${__DICT_PATN_HDR_RECORD__}"
        local entries="${dict#${stripped}}"
#echo "@@ @@ stripped entries before all check:'$(dict_print_raw "${entries}")'" >&2
        if ! "${all}"; then
#echo "@@ @@ stripped entries -require entry separator at head'" >&2
          entries="${__DICT_ENTRY_SEPARATOR__}${entries}"
        fi
#echo "@@ @@ stripped entries after all check:'$(dict_print_raw "${entries}")'" >&2
        if [ "${entries}" != "${dict}" ]; then
            __dict_return_value__="${entries}"
        fi
    }

    __dict_get_size__() {
        local dict="${1}"
        local size="${dict#${__DICT_HDR_ENTRY_BASE__}}"
        size="${size%%${__DICT_ENTRY_SEPARATOR__}*}"
#echo "@@ @@ __dict_get_size__: Size : ${size}" >&2
        __dict_return_value__="${size}"
    }

    __dict_update_size__() {
        local dict="${1}"
        local new_size="${2}"
        __dict_strip_header__ "${1}" "false"
        local dict="${__DICT_HDR_ENTRY_BASE__}${new_size}${__dict_return_value__}"
        __dict_return_value__="${dict}"
#echo "@@ @@ __dict_update_size__: new_size: ${new_size}; return value: '$(dict_print_raw "${__dict_return_value__}")'" >&2
    }

    __dict_add_to_size__() {
        local dict="${1}"
        local change="${2}"
        __dict_get_size__ "${dict}"
        __dict_update_size__ "${dict}" $(( ${__dict_return_value__}+${change} ))
    }

    __dict_prepare_value_for_nesting__() {
        local value="${1}"
        __dict_return_value__="$(sed "s/${__DICT_US__}/${__DICT_GS__}${__DICT_US__}/g; s/${__DICT_RS__}/${__DICT_GS__}${__DICT_RS__}/g" << EOF
${value}
EOF
)"
    }

    __dict_prepare_value_for_unnesting__() {
        local value="${1}"
        __dict_return_value__="$(sed "s/${__DICT_GS__}${__DICT_US__}/${__DICT_US__}/g; s/${__DICT_GS__}${__DICT_RS__}/${__DICT_RS__}/g" << EOF
${value}
EOF
)"
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
#echo "@@ @@ dict passed to __dict_set__:'$(dict_print_raw "${1}")'" >&2
        __dict_strip_header__ "${1}" "false"
        local dict="${__dict_return_value__}"
#echo "@@ @@ stripped dict passed to __dict_set__:'$(dict_print_raw "${dict}")'" >&2
        __dict_decorated_key__ "${2}"
        local dkey="${__dict_return_value__}"
        local value="${3}"

        __dict_get_size__ "${1}"
        local size="${__dict_return_value__}"
        local result="${__DICT_HDR_ENTRY_BASE__}${size}"
        __dict_prefix_entries__ "${dict}" "${dkey}"
        local prefix="${__dict_return_value__}"
        result="${result}${prefix}"
        __dict_new_entry__ "${dkey}" "${value}"
        result="${result}${__dict_return_value__}"

        if [ "${prefix}" = "${dict}" ]; then
#echo "@@ @@ __DICT_SET__: appended entry: $(dict_print_raw "${result}")'" >&2
          __dict_update_size__ "${result}" $(( ${size}+1 ))
#echo "@@ @@ __DICT_SET__:   updated size: $(dict_print_raw "${__dict_return_value__}")'" >&2
        else
          __dict_suffix_entries__ "${dict}" "${dkey}"
          __dict_return_value__="${result}${__dict_return_value__}"
        fi
    }

    __dict_get__() {
        __dict_strip_header__ "${1}" "false"
        local dict="${__dict_return_value__}"
        __dict_decorated_key__ "${2}"
        __dict_value__ "${dict}" "${__dict_return_value__}"
    }

    __dict_op_recnums__() {
        __dict_return_value__="${3}"
    }

    __dict_pretty_print__() {
        local dict="${1}"
        local pprint_specs="${2}"
        dict_get_simple "${pprint_specs}" "dict_prefix"
        dict_for_each "${dict}" __dict_op_pretty_print_record__ "${pprint_specs}"
        dict_get_simple "${pprint_specs}" "dict_suffix"
    }

    __dict_op_pretty_print_record__() {
        local key="${1}"
        local value="${2}"
        local record_number="${3}"
        local pprint_specs="${4}"
        local record_separator=''
        if [ ${record_number} -gt 1 ]; then
            record_separator="$(dict_get "${pprint_specs}" "record_separator"; echo "${__DICT_GS__}")"
            record_separator="${record_separator%${__DICT_GS__}}"
        fi
        if ! dict_is_dict "${value}"; then
            echo -n "${record_separator}"
            dict_get_simple "${pprint_specs}" "record_prefix"
            dict_get_simple "${pprint_specs}" "key_prefix"
            echo -n "${key}"
            dict_get_simple "${pprint_specs}" "key_suffix"
            dict_get_simple "${pprint_specs}" "value_prefix"
            echo -n "${value}"
            dict_get_simple "${pprint_specs}" "value_suffix"
            dict_get_simple "${pprint_specs}" "record_suffix"
        else
            echo -n "${record_separator}"
            dict_get "${pprint_specs}" "record_prefix"
            dict_get "${pprint_specs}" "key_prefix"
            echo -n ${key}
            dict_get "${pprint_specs}" "key_suffix"
            local indent="$(dict_get "${pprint_specs}" "nesting_indent"; echo "${__DICT_GS__}")"
            indent="${indent%${__DICT_GS__}}"
            if [ -n "${indent}" ]; then
                local pprint_specs_indent="$(echo -n "${pprint_specs}" | sed '2,$s'"/^/${indent}/";  echo "${__DICT_GS__}" )"
                pprint_specs_indent="${pprint_specs_indent%${__DICT_GS__}}"
            else
                local pprint_specs_indent="${pprint_specs}"
            fi
            dict_get "${pprint_specs_indent}" "nesting_prefix"
            __dict_pretty_print__ "${value}" "${pprint_specs_indent}"
            dict_get "${pprint_specs_indent}" "nesting_suffix"
            dict_get "${pprint_specs}" "record_suffix"
        fi
    }
fi

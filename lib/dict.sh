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
# matching, cutting, pasting and (for nesting / unnesting) subsitution via sed
# do not expect any decent perforance.
#
# Use:
# dict_set      to add or update key,value to blank string or existing
#               dict-formatted variable previously returned from dist_set.
# dict_get      to retrieve a value associated with a key in a dict-formatted
#               variable
# dict_remove   to remove the key,value entry in a dict associated with a key.
# dict_to_vars  to convert each key,value in a dict to a variable
# dict_print_raw to print the raw string of a dict variable with substitutions
#               for the US, RS, GS and FS non-printing separator characters.
#               Useful for debugging and similar.
#
# sdict_set, sdict_get, sdict_remove, sdict_to_vars are simpler versions that
# do not support nesting of dict values in other dict variables. They should
# have less overhead (sdict_set and sdict_get in particular require
# substitutions of key,value and entry separator sequences using sed to allow
# dicts to be nested as dict values).
#

__DICT_FS__=$(echo '@' | tr '@' '\034')
__DICT_GS__=$(echo '@' | tr '@' '\035')
__DICT_RS__=$(echo '@' | tr '@' '\036')
__DICT_US__=$(echo '@' | tr '@' '\037')

__DICT_RECORD_SEPARATOR__="${__DICT_RS__}"
__DICT_FIELD_SEPARATOR__="${__DICT_US__}"
__DICT_NESTING_PREFIX__="${__DICT_GS__}"

__DICT_ENTRY_SEPARATOR__="${__DICT_FIELD_SEPARATOR__}${__DICT_RECORD_SEPARATOR__}"

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
    cat << EOF
${dict%${decorated_key}*}
EOF
}

__dict_value_and_suffix_entries__() {
    local dict="${1}"
    local decorated_key="${2}"
    cat << EOF
${dict#*${decorated_key}}
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

dict_print_raw()
{
  local dict="${1}"
  local us_rs_gs_fs_translation='_^]\\'
  if [ $# -ge 2 ]; then
    us_rs_gs_fs_translation="${2}"
  fi
  echo "${dict}" | tr "${__DICT_US__}${__DICT_RS__}${__DICT_GS__}${__DICT_FS__}" "${us_rs_gs_fs_translation}" 
}

sdict_set() {
    local dict="${1}"
    local dkey="$(__dict_decorated_key__ "${2}")"
    local value="${3}"
    cat << EOF
$(__dict_prefix_entries__ "${dict}" "${dkey}")$(__dict_new_entry__ "${dkey}" "${value}")$(__dict_suffix_entries__ "${dict}" "${dkey}")
EOF
}

sdict_get() {
    local dict="${1}"
    local dkey="$(__dict_decorated_key__ "${2}")"
    cat << EOF
$(__dict_value__ "${dict}" "${dkey}")
EOF
}

sdict_remove() {
    local dict="${1}"
    local dkey="$(__dict_decorated_key__ "${2}")"
    cat << EOF
$(__dict_prefix_entries__ "${dict}" "${dkey}")$(__dict_suffix_entries__ "${dict}" "${dkey}")
EOF
}

# Do not execute in subshell to calling context as created
# variables will then not be available to calling context.
sdict_to_vars() {
    local dict="${1}"
    while [ -n "${dict}" ]; do
        local record="${dict%%${__DICT_ENTRY_SEPARATOR__}*}"
        local key="${record%${__DICT_FIELD_SEPARATOR__}*}"
        local value="${record#*${__DICT_FIELD_SEPARATOR__}}"
        local dict="${dict#*${__DICT_ENTRY_SEPARATOR__}}"
#        echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${__DICT_RS__}${DICT___DICT_US__}" '^_' >&2
        read ${key} << EOF 
${value}
EOF
    done
}

dict_set() {
    local value="$(__dict_prepare_value_for_nesting__ "${3}")"
    cat << EOF
$(sdict_set "${1}" "${2}" "${value}")
EOF
}

dict_get() {
    local value="$(sdict_get "${1}" "${2}")"
    cat << EOF
$(__dict_prepare_value_for_unnesting__ "${value}")
EOF
}

dict_remove() {
    cat << EOF
$(sdict_remove "${1}" "${2}")
EOF
}

# Do not execute in subshell to calling context as created
# variables will then not be available to calling context.
dict_to_vars() {
    sdict_to_vars "${1}"
}

#!/bin/sh

# Associative array (aka DICTionary) functions.
#
# Allows string values to be associated with a string keys.
#
# Strings can contain any printable ASCII or UTF-8 encoded characters
# as well as most unprintable characters except ASCII FS, GS, RS and US.
# These are reserved for dict implementation purposes.
#
# Use:
# dict_set      to add or update key,value to blank string or existing
#               dict-formatted variable previously returned from dist_set.
# dict_get      to retrieve a value associated with a key in a dict-formatted
#               variable
# dict_remove   to remove the key,value entry in a dict associated with a key.
# dict_to_vars  to convert each key,value in a dict to a variable


__DICT_FS__=$(echo '@' | tr '@' '\034')
__DICT_GS__=$(echo '@' | tr '@' '\035')
__DICT_RS__=$(echo '@' | tr '@' '\036')
__DICT_US__=$(echo '@' | tr '@' '\037')

__DICT_RECORD_SEPERATOR__="${__DICT_RS__}"
__DICT_FIELD_SEPERATOR__="${__DICT_US__}"
__DICT_NESTING_PREFIX__="${__DICT_GS__}"

dict_set() {
    local dict="${1}"
    local key="${2}${__DICT_FIELD_SEPERATOR__}"
    local value="${3}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        suffix_entries="${value_plus#*${__DICT_RECORD_SEPERATOR__}}"
        if [ "${suffix_entries}" = "${value_plus}" ]; then
            suffix_entries=''
        fi
        cat << EOF
${dict%${key}*}${key}${value}${__DICT_FIELD_SEPERATOR__}${__DICT_RECORD_SEPERATOR__}${suffix_entries}
EOF
    else
        cat << EOF
${dict%}${key}${value}${__DICT_FIELD_SEPERATOR__}${__DICT_RECORD_SEPERATOR__}
EOF
    fi
}

dict_get() {
    local dict="${1}"
    local key="${2}${__DICT_FIELD_SEPERATOR__}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        echo ${value_plus%%${__DICT_FIELD_SEPERATOR__}${__DICT_RECORD_SEPERATOR__}*}
    fi
}

dict_remove() {
    local dict="${1}"
    local key="${2}${__DICT_FIELD_SEPERATOR__}"
    local value="${3}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        suffix_entries="${value_plus#*${__DICT_FIELD_SEPERATOR__}${__DICT_RECORD_SEPERATOR__}}"
        if [ "${suffix_entries}" = "${value_plus}" ]; then
            suffix_entries=''
        fi
        cat << EOF
${dict%${key}*}${suffix_entries}
EOF
    fi
}

# Do not execute in subshell to calling context as created
# variables will then not be available to calling context.
dict_to_vars() {
    local dict="${1}"
    while [ -n "${dict}" ]; do
        local record="${dict%%${__DICT_FIELD_SEPERATOR__}${__DICT_RECORD_SEPERATOR__}*}"
        local key="${record%${__DICT_FIELD_SEPERATOR__}*}"
        local value="${record#*${__DICT_FIELD_SEPERATOR__}}"
        local dict="${dict#*${__DICT_RECORD_SEPERATOR__}}"
#        echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${__DICT_RS__}${DICT___DICT_US__}" '^_' >&2
        read ${key} << EOF 
${value}
EOF
    done
}

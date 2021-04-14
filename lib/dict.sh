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


FS=$(echo '@' | tr '@' '\034')
GS=$(echo '@' | tr '@' '\035')
RS=$(echo '@' | tr '@' '\036')
US=$(echo '@' | tr '@' '\037')

dict_set() {
    local dict="${1}"
    local rec_delimiter="${RS}"
    local key_delimiter="${US}"
    local key="${2}${key_delimiter}"
    local value="${3}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        suffix_entries="${value_plus#*${rec_delimiter}}"
        if [ "${suffix_entries}" = "${value_plus}" ]; then
            suffix_entries=''
        fi
        cat << EOF
${dict%${key}*}${key}${value}${key_delimiter}${rec_delimiter}${suffix_entries}
EOF
    else
        cat << EOF
${dict%}${key}${value}${key_delimiter}${rec_delimiter}
EOF
    fi
}

dict_get() {
    local dict="${1}"
    local rec_delimiter="${RS}"
    local key_delimiter="${US}"
    local key="${2}${key_delimiter}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        echo ${value_plus%%${key_delimiter}${rec_delimiter}*}
    fi
}

dict_remove() {
    local dict="${1}"
    local rec_delimiter="${RS}"
    local key_delimiter="${US}"
    local key="${2}${key_delimiter}"
    local value="${3}"
    local value_plus="${dict#*${key}}"
    if [ "${value_plus}" != "${dict}" ]; then
        suffix_entries="${value_plus#*${key_delimiter}${rec_delimiter}}"
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
    local rec_delimiter="${RS}"
    local key_delimiter="${US}"
    while [ -n "${dict}" ]; do
        local record="${dict%%${key_delimiter}${rec_delimiter}*}"
        local key="${record%${key_delimiter}*}"
        local value="${record#*${key_delimiter}}"
        local dict="${dict#*${rec_delimiter}}"
#        echo "dict:\"${dict}\" record:\"${record}\" key:\"${key}\" value:\"${value}\"" | tr "${RS}${US}" '^_' >&2
        read ${key} << EOF 
${value}
EOF
    done
}

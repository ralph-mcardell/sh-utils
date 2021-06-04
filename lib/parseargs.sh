#!/bin/sh

# Parse (command line) arguments.

. dict

if [ -z ${__parseargs_included_20210604__} ];
then
  __parseargs_included_20210604__=yes

  parseargs_is_argument_parser() {
    if [ $# -ge 1 ] && \
    [ "$(dict_get_simple "${1}" "__PARSEARG_TYPE__")X" = "argument_parserX" ]; then
      true; return
    else
      false; return
    fi    
  }

  parseargs_new_argument_parser() {
    local initial_arguments="$(dict_declare_simple)"
    local parser="$(dict_declare_simple \
                     "__PARSEARG_TYPE__" "argument_parser"
                  )"
    while [ "$#" -gt "1" ]; do
      case ${1} in
        argument_default)
          parser="$(dict_set_simple "${parser}" "argument_default" "${2}")"
          ;;
      esac
      shift 2
    done
    
    parser="$(dict_set "${parser}" "__arguments__" "${initial_arguments}")"
    echo -n "${parser}"
  }

  parseargs_add_argument() {
   __parseargs_abort_if_not_parser__ "${1}" "parseargs_add_argument"
    local argument="$(dict_declare_simple \
                     "__PARSEARG_TYPE__" "argument_parser_argument"
                  )"
    local parser="${1}"
    shift
    while [ "$#" -gt "1" ]; do
      case ${1} in
        name)
          argument="$(dict_set_simple "${argument}" "name" "${2}")"
          ;;
        short)
          argument="$(dict_set_simple "${argument}" "short" "${2}")"
          ;;
        long)
          argument="$(dict_set_simple "${argument}" "long" "${2}")"
          ;;
        destination)
          argument="$(dict_set_simple "${argument}" "destination" "${2}")"
          ;;
        action)
          argument="$(dict_set_simple "${argument}" "action" "${2}")"
          ;;
        default)
          argument="$(dict_set_simple "${argument}" "default" "${2}")"
          ;;
      esac
      shift 2
    done
    local dest=$(dict_get_simple "${argument}" "destination")
    if [ -z "${dest}" ]; then
      dest="$(dict_get_simple "${argument}" "name")"
      if [ -z "${dest}" ]; then
        dest="$(dict_get_simple "${argument}" "long")"
      fi
    fi
    dest="$(__parseargs_sanitise_destination__ "${dest}")"

    if [ -z "${dest}" ]; then
      echo "Error: unable to deduce destination name for argument value." >&2
      exit 1
    fi
    argument="$(dict_set_simple "${argument}" "destination" "${dest}")"

    args="$(dict_get "${parser}" "__arguments__")"
    args="$(dict_set "${args}" "${argument}")"
    parser="$(dict_set "${parser}" "__arguments__" "${args}")"
    echo -n "${parser}"
  }


  __parseargs_abort_if_not_parser__() {
    if ! parseargs_is_argument_parser "${1}"; then
        echo "Oops! First argument passed to ${2} is not an argument parser type. Quitting current (sub-)shell." >&2
        exit 1
    fi
  }

  __parseargs_sanitise_destination__() {
    echo -n "${1}" | tr "-" "_"
  }
fi

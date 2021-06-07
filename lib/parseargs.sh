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
    local positionals="$(dict_declare_simple)"
    local longopts="$(dict_declare_simple)"
    local shortopts="$(dict_declare_simple)"
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
    parser="$(dict_set "${parser}" "__positionals__" "${positionals}")"
    parser="$(dict_set "${parser}" "__longopts__" "${longopts}")"
    parser="$(dict_set "${parser}" "__shortopts__" "${shortopts}")"
    echo -n "${parser}"
  }

  parseargs_add_argument() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_add_argument"
    local argument="$(dict_declare_simple)"
    local parser="${1}"
    local positionals="$(dict_get "${parser}" "__positionals__")"
    local longopts="$(dict_get "${parser}" "__longopts__")"
    local shortopts="$(dict_get "${parser}" "__shortopts__")"
    local optstring="$(dict_get "${parser}" "__optstring__")"
    shift
    while [ "$#" -gt "1" ]; do
      case ${1} in
        name)
          if [ -z "${is_option}" ]; then
            if [ -z "${positional}" ]; then
              positional="${2}"
            else
              echo "ERROR: Argument name attribute specified more than once." >&2
              exit 1
            fi
          else
            echo "ERROR: Both name and long/short specified. Argument cannot be both positional and optional." >&2
            exit 1
          fi
          ;;
        short)
          if [ -z "${positional}" ]; then
            if [ -z "${short_opt}" ]; then
              is_option="true"
              short_opt="${2}"
            else
              echo "ERROR: Argument short attribute specified more than once." >&2
              exit 1
            fi
          else
            echo "ERROR: Both name and long/short specified. Argument cannot be both positional and optional." >&2
            exit 1
          fi
          ;;
        long)
          if [ -z "${positional}" ]; then
            if [ -z "${long_opt}" ]; then
              argument="$(dict_set_simple "${argument}" "long" "${2}")"
              is_option="true"
              long_opt="${2}"
            else
              echo "ERROR: Argument long attribute specified more than once." >&2
              exit 1
            fi
          else
            echo "ERROR: Both name and long/short specified. Argument cannot be both positional and optional." >&2
            exit 1
          fi
          ;;
        destination)
          dest="${2}"
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

    if [ -z "${dest}" ]; then
      dest="${positional}"
      if [ -z "${dest}" ]; then
        dest="${long_opt}"
      fi
    fi
    dest="$(__parseargs_sanitise_destination__ "${dest}")"

    if [ -z "${dest}" ]; then
      echo "Error: unable to deduce destination name for argument value." >&2
      exit 1
    fi

    if [ -n "${positional}" ]; then
      argument="$(dict_set_simple "${argument}" "name" "${2}")"
      positionals="$(dict_set_simple "${positionals}" "$(dict_size "${positionals}")" "${dest}")"
    elif  [ -n "${is_option}" ]; then
      if [ -n "${short_opt}" ]; then
        if [ "${#short_opt}" -ne 1 ]; then
          echo "Error: Argument short option attribute value '${short_opt}' is not a single character." >&2
          exit 1
        fi
        existing="$(dict_get_simple "${shortopts}" "${short_opt}")"
        if [ -n "${existing}" ]; then
          echo "Error: Argument short option attribute value '${short_opt}' given previously." >&2
          exit 1
        fi
        argument="$(dict_set_simple "${argument}" "short" "${short_opt}")"
        shortopts="$(dict_set_simple "${shortopts}" "${short_opt}" "${dest}")"
        optstring="${optstring}${short_opt}"
      fi
      if [ -n "${long_opt}" ]; then
        existing="$(dict_get_simple "${longopts}" "${long_opt}")"
        if [ -n "${existing}" ]; then
          echo "Error: Argument long option attribute value '${long_opt}' given previously." >&2
          exit 1
        fi
        argument="$(dict_set_simple "${argument}" "long" "${long_opt}")"
        longopts="$(dict_set_simple "${longopts}" "${long_opt}" "${dest}")"
      fi
    else
      echo "Error: none of name, long or short attributes provided for argument." >&2
      exit 1
    fi

    argument="$(dict_set_simple "${argument}" "destination" "${dest}")"

    args="$(dict_get "${parser}" "__arguments__")"
    args="$(dict_set "${args}" "${dest}" "${argument}")"
    parser="$(dict_set "${parser}" "__arguments__" "${args}")"
    parser="$(dict_set "${parser}" "__positionals__" "${positionals}")"
    parser="$(dict_set "${parser}" "__longopts__" "${longopts}")"
    parser="$(dict_set_simple "${parser}" "__optstring__" "${optstring}")"

    echo -n "${parser}"
  }

  parseargs_parse_arguments() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_parse_arguments"
    local parser="${1}"
    local arg_specs="$(dict_get "${parser}" "__arguments__")"
    local positionals="$(dict_get "${parser}" "__positionals__")"
    local longopts="$(dict_get "${parser}" "__longopts__")"
    local shortopts="$(dict_get "${parser}" "__shortopts__")"
    local optstring="$(dict_get_simple "${parser}" "__optstring__")"
    local current_positional="0"

    arguments="$(dict_declare_simple)"
    shift
    while [ "$#" -gt "0" ]; do
      dest="$(dict_get_simple "${positionals}" "${current_positional}")"
      if [ -z "${dest}" ]; then
        echo "Too many positional arguments provided, remaining ignored." >&2
        echo -n "${arguments}"
      fi
      current_positional=$((${current_positional}+1))
      attributes="$(dict_get "${arg_specs}" "${dest}")"
      if [ -z "${attributes}" ]; then
        echo "Error (internal). No attrubutes specifying this argument." >&2
        exit 1
      fi
      arguments="$(dict_set_simple "${arguments}" "${dest}" "${1}")"
      shift
    done
    echo -n "${arguments}"
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

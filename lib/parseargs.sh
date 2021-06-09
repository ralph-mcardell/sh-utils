#!/bin/sh

# Parse (command line) arguments.

. dict

if [ -z ${__parseargs_included_20210604__} ];
then
  __parseargs_included_20210604__=yes

  parseargs_is_argument_parser() {
    if [ $# -ge 1 ] && \
    dict_is_dict "${1}" && \
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
    local readonly err_msg_pos_or_opt="Both name and long/short specified. Argument cannot be both positional and optional."
    local is_option=""
    local positional=""
    local short_opt=""
    local long_opt=""
    local dest=""
    shift
    while [ "$#" -gt "1" ]; do
      case ${1} in
        name)
          if [ -z "${is_option}" ]; then
            if [ -z "${positional}" ]; then
              positional="${2}"
            else
              __parseargs_error_exit__ "Argument name attribute specified more than once."
            fi
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
          fi
          ;;
        short)
          if [ -z "${positional}" ]; then
            if [ -z "${short_opt}" ]; then
              is_option="true"
              short_opt="${2}"
            else
              __parseargs_error_exit__ "Argument short attribute specified more than once."
            fi
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
          fi
          ;;
        long)
          if [ -z "${positional}" ]; then
            if [ -z "${long_opt}" ]; then
              argument="$(dict_set_simple "${argument}" "long" "${2}")"
              is_option="true"
              long_opt="${2}"
            else
              __parseargs_error_exit__ "Argument long attribute specified more than once."
            fi
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
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
      __parseargs_error_exit__ "Unable to deduce destination name for argument value from destination, name or long attribute values." >&2
    fi

    if [ -n "${positional}" ]; then
      argument="$(dict_set_simple "${argument}" "name" "${2}")"
      positionals="$(dict_set_simple "${positionals}" "$(dict_size "${positionals}")" "${dest}")"
    elif  [ -n "${is_option}" ]; then
      if [ -n "${short_opt}" ]; then
        if [ "${#short_opt}" -ne 1 ]; then
          __parseargs_error_exit__ "Argument short option attribute value '${short_opt}' is not a single character."
        fi
        local existing="$(dict_get_simple "${shortopts}" "${short_opt}")"
        if [ -n "${existing}" ]; then
          __parseargs_error_exit__ "Argument short option attribute value '${short_opt}' given previously."
        fi
        argument="$(dict_set_simple "${argument}" "short" "${short_opt}")"
        shortopts="$(dict_set_simple "${shortopts}" "${short_opt}" "${dest}")"
        optstring="${optstring}${short_opt}"
      fi
      if [ -n "${long_opt}" ]; then
        local existing="$(dict_get_simple "${longopts}" "${long_opt}")"
        if [ -n "${existing}" ]; then
          __parseargs_error_exit__ "Argument long option attribute value '${long_opt}' given previously."
        fi
        argument="$(dict_set_simple "${argument}" "long" "${long_opt}")"
        longopts="$(dict_set_simple "${longopts}" "${long_opt}" "${dest}")"
      fi
    else
      __parseargs_error_exit__ "None of name, long or short attributes provided for argument."
    fi

    argument="$(dict_set_simple "${argument}" "destination" "${dest}")"

    args="$(dict_get "${parser}" "__arguments__")"
    args="$(dict_set "${args}" "${dest}" "${argument}")"
    parser="$(dict_set "${parser}" "__arguments__" "${args}")"
    parser="$(dict_set "${parser}" "__positionals__" "${positionals}")"
    parser="$(dict_set "${parser}" "__longopts__" "${longopts}")"
    parser="$(dict_set "${parser}" "__shortopts__" "${shortopts}")"
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
    local expected_number_of_positionals="$(dict_size "${positionals}")"
    while [ "$#" -gt "0" ]; do
      dest="$(dict_get_simple "${positionals}" "${current_positional}")"
      if [ -z "${dest}" ]; then
        __parseargs_warn_continue__ "Too many positional arguments provided, remaining ignored."
        echo -n "${arguments}"
        return
      fi
      current_positional=$((${current_positional}+1))
      attributes="$(dict_get "${arg_specs}" "${dest}")"
      if [ -z "${attributes}" ]; then
        __parseargs_error_exit__ "(internal). No attrubutes specifying this argument."
      fi
      arguments="$(dict_set_simple "${arguments}" "${dest}" "${1}")"
      shift
    done
    if [ "${current_positional}" -ne "${expected_number_of_positionals}" ]; then
      __parseargs_error_exit__ "Too few required positional arguments provided. Received ${current_positional}, require ${expected_number_of_positionals}."
    fi
    echo -n "${arguments}"
  }

  __parseargs_warn_continue__() {
    echo "WARNING: ${1}" >&2
  }

  __parseargs_error_exit__() {
    echo "ERROR: ${1}" >&2
    exit 1
  }
  __parseargs_abort_if_not_parser__() {
    if ! parseargs_is_argument_parser "${1}"; then
      __parseargs_error_exit__ "First argument passed to ${2} is not an argument parser type. Quitting current (sub-)shell."
    fi
  }

  __parseargs_sanitise_destination__() {
    echo -n "${1}" | tr "-" "_"
  }
fi

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
    parser="$(dict_set_simple "${parser}" "__optstring__" ":")"
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
    local action=""
    local num_args=''
    local have_default=false
    local have_const=false
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
        nargs)
          num_args="${2}"
          if __parseargs_is_valid_nargs_value__ "${num_args}" "${__PARSEARGS_MAX_NARGS__}"; then
            argument="$(dict_set_simple "${argument}" "nargs" "${num_args}")"
          else
            __parseargs_error_exit__ "nargs value '${num_args}' invalid. Must be integer in the range [1, ${__PARSEARGS_MAX_NARGS__}], '?','*' or '+'."
          fi
          ;;
        const)
          have_const=true
          argument="$(dict_set_simple "${argument}" "const" "${2}")"
          ;;
        default)
          have_default=true
          argument="$(dict_set_simple "${argument}" "default" "${2}")"
          ;;
        required)
          if "${2}"; then
            argument="$(dict_set_simple "${argument}" "required" "true")"
          fi
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
      if [ "${num_args}" = '?' ] && ! ${have_default}; then
        __parseargs_error_exit__ "A default attribute value is required for optional positional argument (nargs=?) '${dest}'." >&2
      fi
      argument="$(dict_set_simple "${argument}" "name" "${2}")"
      positionals="$(dict_set_simple "${positionals}" "$(dict_size "${positionals}")" "${dest}")"
    elif  [ -n "${is_option}" ]; then
      if [ "${num_args}" = '?' ] && ! ${have_const}; then
        __parseargs_error_exit__ "A const attribute value is required for optional arguments with optional value (nargs=?) '${dest}'." >&2
      fi

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
        optstring="${optstring}${short_opt}:"
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
    local positionals_to_parse=true
    arguments="$(dict_declare_simple)"
    shift
    local expected_number_of_positionals="$(dict_size "${positionals}")"
#echo "OPTSTRING:'${optstring}'." >&2
#echo "PARSING:'$*'." >&2
    while [ "$#" -gt "0" ]; do
      __parseargs_parse_short_options__ "${arguments}" "${optstring}" "${shortopts}" "${arg_specs}" "$@"
      arguments="${__parseargs_return_value__}"
      shift ${__parseargs_shift_caller_args_by__}
#echo "  PARSE ARGS: shifted by: ${__parseargs_shift_caller_args_by__}; remaining arguments to parse: '$*'" >&2
      if [ "$#" -gt "0" ]; then
        __parseargs_parse_long_option__ "${arguments}" "${longopts}" "${arg_specs}" "$@"
        if [ "${__parseargs_shift_caller_args_by__}" -eq "0" ]; then
          if "${positionals_to_parse}"; then
            __parseargs_parse_positional_argument__ "${arguments}" "${positionals}" "${current_positional}" "${arg_specs}" "$@"
            if [ "${__parseargs_shift_caller_args_by__}" -eq "0" ]; then
              positionals_to_parse=false
              __parseargs_shift_caller_args_by__=1
            else
              current_positional=$((${current_positional}+1))
            fi
          else
            __parseargs_shift_caller_args_by__=1
          fi
        fi
        arguments="${__parseargs_return_value__}"
        shift ${__parseargs_shift_caller_args_by__}
      fi
    done
    while [ "${current_positional}" -ne "${expected_number_of_positionals}" ]; do
      __parseargs_parse_positional_argument__ "${arguments}" "${positionals}" "${current_positional}" "${arg_specs}"
      arguments="${__parseargs_return_value__}"
      current_positional=$((${current_positional}+1))
    done
    __parseargs_validate_and_fixup_arguments__ "${parser}" "${arguments}"
    echo -n "${__parseargs_return_value__}"
  }

  # Details

  readonly __PARSEARGS_MAX_NARGS__="$(( $(getconf ARG_MAX)/2 ))"
  __parseargs_return_value__=""
  __parseargs_shift_caller_args_by__="0"

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

  __parseargs_is_option_string__() {
    local readonly option_name_suffix="${1#-}"
    if [ "${option_name_suffix}" = "${1}" ]; then
      false; return
    else
      true; return
    fi
  }

  __parseargs_is_option_string_or_empty__() {
    if [ -z "${1}" ] || __parseargs_is_option_string__ "${1}"; then
      true; return
    else
      false; return
    fi
  }

  __parseargs_option_name_from_long_option_string__() {
    __parseargs_return_value__="${1#--}"
  }

  __parseargs_split_string_on_eq_lhs__() {
    __parseargs_return_value__="${1%%\=*}"
  }

  __parseargs_split_string_on_eq_rhs__() {
    __parseargs_return_value__="${1#*'='}"
  }

  __parseargs_is_natural_number__() {
    case "${1}" in
      ''|*[!0-9]*)
        false; return
        ;;
      *)
        true; return
        ;;
    esac
  }

  __parseargs_is_glob_character__() {
    case "${1}" in
      '?'|'*'|'+')
        true; return
        ;;
      *)
        false; return
        ;;
    esac
  }

  __parseargs_is_valid_nargs_number__() {
    [ "${#1}" -le 18 ] \
    && __parseargs_is_natural_number__ "${1}" \
    && [ "${1}" -gt "0" ] \
    && [ "${1}" -le "${2}" ]
    return
  }

  __parseargs_is_valid_nargs_value__() {
    __parseargs_is_glob_character__  "${1}" \
    || __parseargs_is_valid_nargs_number__ "${1}" "${2}"
    return
  }

  __parseargs_parse_short_options__() {
    __parseargs_return_value__="${1}"
    local optstring="${2}"
    local shortopts="${3}"
    local arg_specs="${4}"
    local dest=""
    shift 4
    __parseargs_shift_caller_args_by__="0"
    while getopts "${optstring}" opt; do
#echo "GETOPTS opt=${opt}; OPTARG=${OPTARG}; OPTIND=${OPTIND}; dest=${dest} args='$*'" >&2
      if [ "${opt}" = "?" ]; then
        if [ "${OPTARG}" = "-" ]; then
        # found --, long option prefix
          break
        fi
        __parseargs_error_exit__ "Unknown short option -${OPTARG}."
      fi
      local call_shift_by_increment=$(( ${OPTIND}-2 ))
      if [ "${opt}" = ":" ] ; then
        opt="${OPTARG}"
        OPTARG=''
        call_shift_by_increment=$(( ${call_shift_by_increment}+1 ))
      fi
      dest="$(dict_get_simple "${shortopts}" "${opt}")"
      if [ -z "${dest}" ]; then
        __parseargs_error_exit__ "(internal) YYY Argument specification key for short option -${opt} not found."
      fi
      shift $(( ${OPTIND}-1 ))
      local shift_by="${__parseargs_shift_caller_args_by__}"
      if [ -n "${OPTARG}" ]; then
        set -- "${OPTARG}" "$@"
      fi

#echo "remaining arg count: $#; caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}" >&2
#echo "  BEFORE: caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}; args='$*'" >&2
      __parseargs_add_arguments__ "${__parseargs_return_value__}" "${arg_specs}" "${dest}" "const" "Short option -${opt}" "$@"
      shift_by=$(( ${__parseargs_shift_caller_args_by__}-${shift_by} ))
#echo "   AFTER: caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}; args='$*'" >&2
      if [ "${shift_by}" -gt '0' ]; then
        shift "${shift_by}"
      fi
      __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+${call_shift_by_increment} ))
      OPTIND=1
#echo "    END: Caller shift args by: ${__parseargs_shift_caller_args_by__}; remaining arguments: '$*'" >&2        
    done
  }

  __parseargs_parse_long_option__() {
    arguments="${1}"
    local longopts="${2}"
    local arg_specs="${3}"
    shift 3
    __parseargs_option_name_from_long_option_string__ "${1}"
    local readonly option_string="${__parseargs_return_value__}"
    if [ "${1}" = "--" ] || [ "${option_string}" = "${1}" ]; then
    # Either just '--' or did not find -- prefix, not a long option
      __parseargs_shift_caller_args_by__=0
      return
    fi
    __parseargs_split_string_on_eq_lhs__ "${option_string}"
    dest="$(dict_get_simple "${longopts}" "${__parseargs_return_value__}")"
    if [ -z "${dest}" ]; then
      __parseargs_error_exit__ "Unknown long option --${__parseargs_return_value__}."
    fi
    shift
    __parseargs_split_string_on_eq_rhs__ "${option_string}"
    if [ "${__parseargs_return_value__}" !=  "${option_string}" ]; then
      set -- "${__parseargs_return_value__}" "$@"
    else
        __parseargs_shift_caller_args_by__=1
    fi
    __parseargs_add_arguments__ "${arguments}" "${arg_specs}" "${dest}" "const" "Long option --${__parseargs_return_value__}" "$@"
  }

  __parseargs_parse_positional_argument__() {
    __parseargs_return_value__="${1}"
    local positionals="${2}"
    local current_positional="${3}"
    local arg_specs="${4}"
    shift 4
    dest="$(dict_get_simple "${positionals}" "${current_positional}")"
    if [ -z "${dest}" ]; then
      __parseargs_warn_continue__ "Too many positional arguments provided, remaining ignored."
      __parseargs_shift_caller_args_by__=0
      return
    fi
    __parseargs_add_arguments__ "${__parseargs_return_value__}" "${arg_specs}" "${dest}" "default" "Positional #$(( ${current_positional}+1 )), '${dest}'," "$@" 
  }

  __parseargs_add_arguments__() {
    local arguments="${1}"
    local arg_specs="${2}"
    local dest="${3}"
    local missing_arg_key="${4}"
    local arg_desc="${5}"
    shift 5
    if [ $# -gt 0 ] && [ -z "$*" ]; then
      # if all remaining arguments empty, consume them
      shift $#
    fi
    local attributes="$(dict_get "${arg_specs}" "${dest}")"
    if [ -z "${attributes}" ]; then
      __parseargs_error_exit__ "(internal). ${arg_desc}: no attrubutes specifying this argument."
    fi

    local nargs="$(dict_get_simple "${attributes}" "nargs" )"
    local missing_arg_value="-"
    
#echo "> ADD ARGS (${arg_desc}; args='$*', count=$#):" >&2
#echo "  dest:${dest}; shift by:${__parseargs_shift_caller_args_by__}; attributes:${attributes}; missing_arg_key:${missing_arg_key}" >&2
    local on_missing='error'

    case "${nargs}" in
      '?')
        nargs=''
        on_missing='value'
        ;;
      '*')
        nargs="${__PARSEARGS_MAX_NARGS__}"
        on_missing='break'
        ;;
      '+')
        nargs="${__PARSEARGS_MAX_NARGS__}"
        on_missing='error_on_first'
        ;;
      *)
        ;;
    esac
    if [ "${on_missing}" = "value" ]; then
      missing_arg_value="$(dict_get_simple "${attributes}" "${missing_arg_key}" )"
      if [ -z "${missing_arg_value}" ]; then
      #  __parseargs_error_exit__ "(internal). ${arg_desc}: cannot retrieve value for missing argument '${missing_arg_key}' value."
        on_missing='error'
      fi
    fi
    if [ -z "${nargs}" ]; then
      __parseargs_add_argument__ "${arguments}" "${dest}" "${on_missing}" "${missing_arg_value}" "${arg_desc}" "$@"
#echo "  Returning: shift by:${__parseargs_shift_caller_args_by__}; value:${__parseargs_return_value__}" >&2
#echo "< ADD ARGS(scalar)" >&2
      return
    fi

    local one_argument="$(dict_declare_simple)"
    local argument_list="$(dict_declare_simple)"
    local argument_index='0'
    local stashed_shift_caller_args_by="${__parseargs_shift_caller_args_by__}"
    local accumulated_shift_count="0"
    while [ "${nargs}" -ne "0" ]; do
      __parseargs_shift_caller_args_by__=0
      __parseargs_add_argument__ "${one_argument}" "${dest}" "${on_missing}" "${missing_arg_value}" "${arg_desc}" "$@"
      if [ -z "${__parseargs_return_value__}" ]; then
        break
      fi
      if [ "${on_missing}" = 'error_on_first' ]; then
        on_missing='break'
      fi
      local value="$(dict_get_simple "${__parseargs_return_value__}" "${dest}")"
      if [ -z "${value}" ]; then
        __parseargs_error_exit__ "(internal). ${arg_desc}: cannot retrieve value for argument value #$(( ${argument_index}+1 ))."
      fi
      argument_list="$(dict_set_simple "${argument_list}" "${argument_index}" "${value}")"
      nargs="$(( ${nargs}-1 ))"
      argument_index="$(( ${argument_index}+1 ))"
      accumulated_shift_count="$(( ${accumulated_shift_count}+${__parseargs_shift_caller_args_by__} ))"
      shift "${__parseargs_shift_caller_args_by__}"
    done
    __parseargs_shift_caller_args_by__="$(( ${stashed_shift_caller_args_by}+${accumulated_shift_count} ))"
    __parseargs_return_value__="$(dict_set "${arguments}" "${dest}" "${argument_list}")"
#echo "  Returning: shift by:${__parseargs_shift_caller_args_by__}; value:${__parseargs_return_value__}" >&2
#echo "< ADD ARGS(list ${argument_index}):" >&2
  }

  __parseargs_add_argument__() {
    __parseargs_return_value__="${1}"
    local dest="${2}"
    local on_missing="${3}"
    local missing_arg_value="${4}"
    local arg_desc="${5}"
    shift 5
    if [ "$#" -gt "0" ]; then
      if __parseargs_is_option_string__ "${1}"; then
        if [ "${1}" = "--" ]; then
          shift
          if [ "$#" -gt "0" ]; then
            __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+1 ))
          fi
        else
          # Found option-like string where argument expected:
          # eat all remaining call arguments to force error
          shift $#
        fi
      fi
      if [ "$#" -gt "0" ]; then
        local arg_value="${1}"
#echo "    Argument found: '${arg_value}'" >&2
        __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" "${dest}" "${arg_value}")"
        __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+1 ))
        return
      fi
    fi
#echo "    Argument missing" >&2
    case "${on_missing}" in
      'value')
        __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" "${dest}" "${missing_arg_value}")"
        ;;
      'error'|'error_on_first')
        __parseargs_error_exit__ "${arg_desc} is missing an argument value."
        ;;
      'break')
        __parseargs_return_value__=''
        ;;
      *)
        __parseargs_error_exit__ "(internal) ${arg_desc} : unrecognised missing argument value action '${on_missing}'."
        ;;
    esac
  }

  __parseargs_validate_and_fixup_arguments__() {
    local parser="${1}"
    local arguments="${2}"
    local arg_specs="$(dict_get "${parser}" "__arguments__")"
    local positionals="$(dict_get "${parser}" "__positionals__")"
    local longopts="$(dict_get "${parser}" "__longopts__")"
    local shortopts="$(dict_get "${parser}" "__shortopts__")"
    __parseargs_return_value__="${arguments}"
    dict_for_each "${arg_specs}" "__parseargs_op_validate_and_fixup_argument__" "${positionals}" "${shortopts}" "${longopts}"
  }

  __parseargs_op_validate_and_fixup_argument__() {
    local dest="${1}"
    local arg_spec="${2}"
    local record_number="${3}"
    local positionals="${4}"
    local shortopts="${5}"
    local longopts="${6}"
    local arguments="${__parseargs_return_value__}"
    local arg="$(dict_get_simple "${arguments}" "${dest}")"
    if [ -z "${arg}" ]; then
      local default="$(dict_get_simple "${arg_spec}" "default")"
      if [ -n "${default}" ]; then
        arguments="$(dict_set_simple "${arguments}" "${dest}" "${default}")"
      else
        local required="$(dict_get_simple "${arg_spec}" "required")"
        if [ -n "${required}" ] && "${required}"; then
          local optname="$(dict_get_simple "${arg_spec}" "long")"
          if [ -z "${optname}" ]; then
            optname="-$(dict_get_simple "${arg_spec}" "short")"
          else
            optname="--${optname}"
          fi
          __parseargs_error_exit__ "Required option ${optname} was not provided."
        fi
      fi
    fi
    __parseargs_return_value__="${arguments}"
  }
fi

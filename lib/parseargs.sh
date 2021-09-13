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
    local empty_dict="$(dict_declare_simple)"
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
    
    parser="$(dict_set "${parser}" "__arguments__" "${empty_dict}")"
    parser="$(dict_set "${parser}" "__positionals__" "${empty_dict}")"
    parser="$(dict_set "${parser}" "__longopts__" "${empty_dict}")"
    parser="$(dict_set "${parser}" "__shortopts__" "${empty_dict}")"
    parser="$(dict_set "${parser}" "__subparsers__" "${empty_dict}")"
    parser="$(dict_set "${parser}" "__sp_aliases__" "${empty_dict}")"
    parser="$(dict_set_simple "${parser}" "__optstring__" ":")"
    echo -n "${parser}"
  }

  parseargs_add_argument() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_add_argument"
    local argument="$(dict_declare_simple)"
    local parser="${1}"
    local positionals=''
    local longopts=''
    local shortopts=''
    local optstring=''
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
    local have_required=false
    local have_choices=false
    shift
    while [ "$#" -gt "1" ]; do
      case ${1} in
        name)
          if [ -z "${is_option}" ]; then
            __parseargs_abort_if_have_attribute_value__ "${positional}" 'name'
            positional="${2}"
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
          fi
          ;;
        short)
          if [ -z "${positional}" ]; then
            __parseargs_abort_if_have_attribute_value__ "${short_opt}" 'short'
            is_option="true"
            short_opt="${2}"
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
          fi
          ;;
        long)
          if [ -z "${positional}" ]; then
            __parseargs_abort_if_have_attribute_value__ "${long_opt}" 'long'
            argument="$(dict_set_simple "${argument}" "long" "${2}")"
            is_option="true"
            long_opt="${2}"
          else
            __parseargs_error_exit__ "${err_msg_pos_or_opt}"
          fi
          ;;
        destination)
          __parseargs_abort_if_have_attribute_value__ "${dest}" 'destination'
          dest="${2}"
          ;;
        action)
          __parseargs_abort_if_have_attribute_value__ "${action}" 'action'
          action="${2}"
          ;;
        nargs)
          __parseargs_abort_if_have_attribute_value__ "${num_args}" 'nargs'
          num_args="${2}"
          if __parseargs_is_valid_nargs_value__ "${num_args}" "${__PARSEARGS_MAX_NARGS__}"; then
            argument="$(dict_set_simple "${argument}" "nargs" "${num_args}")"
          else
            __parseargs_error_exit__ "nargs value '${num_args}' invalid. Must be integer in the range [1, ${__PARSEARGS_MAX_NARGS__}], '?','*' or '+'."
          fi
          ;;
        const)
          __parseargs_abort_if_attribute_flag_set__ ${have_const} 'const'
          have_const=true
          argument="$(dict_set_simple "${argument}" "const" "${2}")"
          ;;
        default)
          __parseargs_abort_if_attribute_flag_set__ ${have_default} 'default'
          have_default=true
          argument="$(dict_set_simple "${argument}" "default" "${2}")"
          ;;
        required)
          __parseargs_abort_if_attribute_flag_set__ ${have_required} 'required'
          if "${2}"; then
            argument="$(dict_set_simple "${argument}" "required" "true")"
            have_required=true
          fi
          ;;
        choices)
          __parseargs_abort_if_attribute_flag_set__ ${have_choices} 'choices'
          if dict_is_dict "${2}"; then
            argument="$(dict_set "${argument}" "choices" "${2}")"
            have_choices=true
          else
            __parseargs_error_exit__ "Argument choices attribute value is not a dict(ionary)."
          fi
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
    local argument_key="${dest}"

    if [ -z "${action}" ]; then
      action="store"
    fi

    if [ -z "${dest}" ]; then
      __parseargs_error_exit__ "Unable to deduce destination name for argument value from destination, name or long attribute values." >&2
    fi

    if [ -n "${positional}" ]; then
      if [ "${action}" != 'store' ] && [ "${action}" != 'sub_command' ]; then
        __parseargs_error_exit__ "Action attribute value '${action}' cannot be used for positional arguments '${dest}'." >&2
      fi
      if [ "${num_args}" = '?' ] && ! ${have_default}; then
        __parseargs_error_exit__ "A default attribute value is required for optional positional argument (nargs=?) '${dest}'." >&2
      fi
      argument="$(dict_set_simple "${argument}" "name" "${2}")"
      positionals="$(dict_get "${parser}" "__positionals__")"
      local pos_id="$(dict_size "${positionals}")"
      argument_key="${argument_key}${pos_id}"
      positionals="$(dict_set_simple "${positionals}" "${pos_id}" "${argument_key}")"
    elif  [ -n "${is_option}" ]; then
      if [ "${num_args}" = '?' ] && ! ${have_const}; then
        __parseargs_error_exit__ "A const attribute value is required for optional arguments with optional value (nargs=?) '${dest}'." >&2
      fi

      if [ -n "${short_opt}" ]; then
        if [ "${#short_opt}" -ne 1 ]; then
          __parseargs_error_exit__ "Argument short option attribute value '${short_opt}' is not a single character."
        fi
        shortopts="$(dict_get "${parser}" "__shortopts__")"
        local existing="$(dict_get_simple "${shortopts}" "${short_opt}")"
        if [ -n "${existing}" ]; then
          __parseargs_error_exit__ "Argument short option attribute value '${short_opt}' given previously."
        fi
        argument="$(dict_set_simple "${argument}" "short" "${short_opt}")"
        argument_key="${argument_key}${short_opt}"
        optstring="$(dict_get "${parser}" "__optstring__")"
        shortopts="$(dict_set_simple "${shortopts}" "${short_opt}" "${argument_key}")"
        optstring="${optstring}${short_opt}${opt_string_arg_char}"
      fi
      if [ -n "${long_opt}" ]; then
        longopts="$(dict_get "${parser}" "__longopts__")"
        local existing="$(dict_get_simple "${longopts}" "${long_opt}")"
        if [ -n "${existing}" ]; then
          __parseargs_error_exit__ "Argument long option attribute value '${long_opt}' given previously."
        fi
        argument="$(dict_set_simple "${argument}" "long" "${long_opt}")"
        if [ "${argument_key}" =  "${dest}" ]; then
        # not set already by short option handling, set here
        # Note: argument can have short and long option forms
          argument_key="${argument_key}${long_opt}"
        fi
        longopts="$(dict_set_simple "${longopts}" "${long_opt}" "${argument_key}")"
      fi
    else
      __parseargs_error_exit__ "None of name, long or short attributes provided for argument."
    fi

    argument="$(dict_set_simple "${argument}" "destination" "${dest}")"

    case "${action}" in
      store|append|extend)
        if [ -n "${short_opt}" ]; then
          optstring="${optstring}:"
        fi
        ;;
      sub_command | sub_argument)
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'sub_command' or 'sub_argument' action attributes '${dest}'." >&2
        fi
        if "${have_const}"; then
          __parseargs_error_exit__ "Cannot specify a const attribute value for arguments with 'sub_command' or 'sub_argument' action attributes '${dest}'." >&2
        fi
        if [ -n "${short_opt}" ]; then
          optstring="${optstring}:"
        fi
        ;;
      store_const|append_const)
        if ! "${have_const}"; then
          __parseargs_error_exit__ "A const attribute value is required for arguments with 'store_const' or 'append_const' action attribute '${dest}'." >&2
        fi
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'store_const' or 'append_const' action attribute '${dest}'." >&2
        fi
        ;;
      store_true|store_false)
        if "${have_default}" || "${have_const}"; then
          __parseargs_error_exit__ "Cannot specify a default or const attribute value for arguments with 'store_true' or 'store_false' action attributes '${dest}'." >&2
        fi
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'store_true' or 'store_false' action attributes '${dest}'." >&2
        fi
        have_default=true
        if [ "${action}" = 'store_true' ]; then
          argument="$(dict_set_simple "${argument}" "default" false)"
        else
          argument="$(dict_set_simple "${argument}" "default" true)"
        fi
        ;;
      count)
        if "${have_const}" || [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify a const or nargs attribute value for arguments with 'count' action attribute '${dest}'." >&2
        fi
        ;;
      *)
        __parseargs_error_exit__ "Unrecognised action attribute value '${action}' for argument '${dest}'." >&2
        ;;
    esac
    argument="$(dict_set_simple "${argument}" "action" "${action}")"

    args="$(dict_get "${parser}" "__arguments__")"
    args="$(dict_set "${args}" "${argument_key}" "${argument}")"
    parser="$(dict_set "${parser}" "__arguments__" "${args}")"
    if [ -n "${positional}" ]; then    
      parser="$(dict_set "${parser}" "__positionals__" "${positionals}")"
    fi
    if [ -n "${long_opt}" ]; then
      parser="$(dict_set "${parser}" "__longopts__" "${longopts}")"
    fi
    if [ -n "${short_opt}" ]; then
      parser="$(dict_set "${parser}" "__shortopts__" "${shortopts}")"
      parser="$(dict_set_simple "${parser}" "__optstring__" "${optstring}")"
    fi
    echo -n "${parser}"
  }

  parseargs_add_sub_parser() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_add_sub_parser"
    if ! parseargs_is_argument_parser "${3}"; then
      __parseargs_error_exit__ "Third (sub-parser) argument passed to parseargs_add_sub_parser is not an argument parser type. Quitting current (sub-)shell."
    fi
    local parser="${1}"
    local subparser_id="${2}"
    local subparser="${3}"
    shift 3
    local subparsers="$(dict_get "${parser}" "__subparsers__")"
    if [ -z "${subparsers}" ]; then
      subparsers="$(dict_declare_simple)"
    fi
    subparsers="$(dict_set "${subparsers}" "${subparser_id}" "${subparser}")"
    parser="$(dict_set "${parser}" "__subparsers__" "${subparsers}")"

    if [ "$#" -gt "0" ]; then
      local aliases="$(dict_get "${parser}" "__sp_aliases__")"
      if [ -z "${aliases}" ]; then
        aliases="$(dict_declare_simple)"
      fi
      while [ "$#" -gt "0" ]; do
        aliases="$(dict_set_simple "${aliases}" "${1}" "${subparser_id}")"
        shift
      done
      parser="$(dict_set "${parser}" "__sp_aliases__" "${aliases}")"
    fi
    echo -n "${parser}"
  }

  parseargs_parse_arguments() {
    __parseargs_parse_arguments__ "$@"
    echo -n "${__parseargs_return_value__}"
  }

  # Details

  readonly __PARSEARGS_MAX_NARGS__="$(( $(getconf ARG_MAX)/2 ))"
  __parseargs_return_value__=""
  __parseargs_shift_caller_args_by__="0"
  __parseargs_current_positional__="0"

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
  
  __parseargs_abort_if_have_attribute_value__() {
    if [ -n "${1}" ]; then
      __parseargs_error_exit__ "Argument ${2} attribute specified more than once."
    fi
  }
  
  __parseargs_abort_if_attribute_flag_set__() {
    if "${1}"; then
      __parseargs_error_exit__ "Argument ${2} attribute specified more than once."
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

  __parseargs_set_parse_specs__() {
    local parser="${1}"
    __parseargs_arg_specs__="$(dict_get "${parser}" "__arguments__")"
    __parseargs_positionals__="$(dict_get "${parser}" "__positionals__")"
    __parseargs_longopts__="$(dict_get "${parser}" "__longopts__")"
    __parseargs_shortopts__="$(dict_get "${parser}" "__shortopts__")"
    __parseargs_optstring__="$(dict_get_simple "${parser}" "__optstring__")"
    __parseargs_subparsers__="$(dict_get "${parser}" "__subparsers__")"
    __parseargs_subparser_alias__="$(dict_get "${parser}" "__sp_aliases__")"    
  }

  __parseargs_split_string_on_arg_rhs__() {
    __parseargs_return_value__="${1#*"${2}"}"
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

  __parseargs_parse_arguments__() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_parse_arguments"
    local parser="${1}"
    __parseargs_set_parse_specs__ "${parser}"
    __parseargs_current_positional__="0"
    local positionals_to_parse=true
    arguments="$(dict_declare_simple)"
    shift
    local expected_number_of_positionals="$(dict_size "${__parseargs_positionals__}")"
#echo "OPTSTRING:'${optstring}'." >&2
#echo "Expected number of positional (start args): ${expected_number_of_positionals}" >&2
    while [ "$#" -gt "0" ]; do
        if [ "${__parseargs_current_positional__}" -gt "${expected_number_of_positionals}" ]; then
          positionals_to_parse=false
        fi
        __parseargs_parse_argument__ "${arguments}" "${positionals_to_parse}" '*' "$@"
        arguments="${__parseargs_return_value__}"
        shift ${__parseargs_shift_caller_args_by__}
    done
#echo "Expected number of positional (end args): ${expected_number_of_positionals}, current positional: ${__parseargs_current_positional__}" >&2
    while [ "${__parseargs_current_positional__}" -ne "${expected_number_of_positionals}" ]; do
      __parseargs_parse_positional_argument__ "${arguments}" "${__parseargs_current_positional__}"
      arguments="${__parseargs_return_value__}"
      __parseargs_current_positional__=$((${__parseargs_current_positional__}+1))
    done
    __parseargs_validate_and_fixup_arguments__ "${arguments}"
  }

  __parseargs_parse_argument__() {
    local arguments="${1}"
    local positionals_to_parse="${2}"
    local multiplicity="${3}"
    shift 3
#echo "PARSING:'$*'." >&2
    __parseargs_parse_short_options__ "${arguments}" "${multiplicity}" "$@"
    arguments="${__parseargs_return_value__}"
    local short_args_shift_by=${__parseargs_shift_caller_args_by__}
#echo "  PARSE ARGS ( short opt): shifting by: ${__parseargs_shift_caller_args_by__}; remaining arguments to parse: '$*', arg count:$#" >&2
    if [ "${multiplicity}" = '*' ] || [ ${__parseargs_shift_caller_args_by__} -eq 0 ]; then
      shift ${__parseargs_shift_caller_args_by__}
      if [ "$#" -gt "0" ]; then
        __parseargs_parse_long_option__ "${arguments}" "$@"
#echo "  PARSE ARGS (  long opt): shifted by: ${__parseargs_shift_caller_args_by__}; remaining arguments to parse: '$*', arg count:$#" >&2
        if [ "${__parseargs_shift_caller_args_by__}" -eq "0" ]; then
          if "${positionals_to_parse}"; then
            __parseargs_parse_positional_argument__ "${arguments}" "${__parseargs_current_positional__}" "$@"
#echo "  PARSE ARGS (positional): shifted by: ${__parseargs_shift_caller_args_by__}; remaining arguments to parse: '$*', arg count:$#" >&2
            if [ "${__parseargs_shift_caller_args_by__}" -eq "0" ]; then
              __parseargs_shift_caller_args_by__=1
            else
              __parseargs_current_positional__=$((${__parseargs_current_positional__}+1))
            fi
          else
            __parseargs_shift_caller_args_by__=1
            __parseargs_return_value__="${arguments}"
          fi
        fi
        __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+${short_args_shift_by} ))
      fi
    fi
  }

  __parseargs_parse_short_options__() {
    arguments="${1}"

  # '*': 0 or more short option clumps until next not short option(+arguments) or end
  # '?': 0 or 1 clump.
  # a short option 'clump' requires only one hyphen ( - ) short option prefix
    multiplicity="${2}"
    local arg_spec_key=""
    local accumulated_opt=''
    shift 2
    __parseargs_shift_caller_args_by__="0"
    while getopts "${__parseargs_optstring__}" opt; do
#echo "GETOPTS opt=${opt}; OPTARG=${OPTARG}; OPTIND=${OPTIND}; arg_spec_key=${arg_spec_key} args='$*'" >&2
      if [ "${opt}" = "?" ]; then
        if [ "${OPTARG}" = "-" ]; then
        # found --, long option prefix
          break
        fi
        __parseargs_error_exit__ "Unknown short option -${OPTARG}."
      fi
      local call_shift_by_increment=$(( ${OPTIND}-2 ))
      local reset_optind=false
      if [ -n "${OPTARG}" ]; then
        reset_optind=true
      fi
      if [ "${opt}" = ":" ] ; then
        opt="${OPTARG}"
        OPTARG=''
      fi

    # If not resetting optind then option is an argumentless flag and may be
    # one of a clump of flags: -xyz or even -vvvv
    # In such cases it is necessary to detect the final option character
    # so as to advance to the next argument on the command line
      if ! ${reset_optind}; then
        accumulated_opt="${accumulated_opt}${opt}"
        __parseargs_split_string_on_arg_rhs__ "${1}" "${accumulated_opt}"
#echo "__parseargs_split_string_on_arg_rhs__ '${1}' '${accumulated_opt}' -> '${__parseargs_return_value__}'" >&2
       if [ -z "${__parseargs_return_value__}" ]; then
          reset_optind=true
          accumulated_opt=''
        fi
      fi
      if  ${reset_optind}; then
        shift $(( ${OPTIND}-1 ))
      fi
      if [ -z "${OPTARG}" ] && ${reset_optind}; then
        call_shift_by_increment=$(( ${call_shift_by_increment}+1 ))
      fi
      arg_spec_key="$(dict_get_simple "${__parseargs_shortopts__}" "${opt}")"
      if [ -z "${arg_spec_key}" ]; then
        __parseargs_error_exit__ "(internal) Argument specification key for short option -${opt} not found."
      fi

      local shift_by="${__parseargs_shift_caller_args_by__}"
      if [ -n "${OPTARG}" ]; then
        set -- "${OPTARG}" "$@"
      fi
#echo "remaining arg count: $#; caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}" >&2
#echo "  BEFORE: caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}; args='$*'" >&2
      __parseargs_process_argument_action__ "${arguments}" "${arg_spec_key}" "const" "Short option -${opt}" "$@"
      arguments="${__parseargs_return_value__}"
      shift_by=$(( ${__parseargs_shift_caller_args_by__}-${shift_by} ))
#echo "   AFTER: next optind=${next_optind}; caller shift by=${__parseargs_shift_caller_args_by__}; local shift by=${shift_by}; args='$*'" >&2
      if [ "${shift_by}" -gt '0' ]; then
        shift "${shift_by}"
      fi
      __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+${call_shift_by_increment} ))
      if ${reset_optind}; then
        if [ "${multiplicity}" = '?' ]; then
          break
        fi
        OPTIND=1
      fi
#echo "     END: Caller shift args by: ${__parseargs_shift_caller_args_by__}; remaining arguments: '$*'" >&2        
    done
    __parseargs_return_value__="${arguments}"
  }

  __parseargs_parse_long_option__() {
    arguments="${1}"
    shift
    __parseargs_option_name_from_long_option_string__ "${1}"
    local readonly option_string="${__parseargs_return_value__}"
    if [ "${1}" = "--" ] || [ "${option_string}" = "${1}" ]; then
    # Either just '--' or did not find -- prefix, not a long option
      __parseargs_shift_caller_args_by__=0
      return
    fi
    __parseargs_split_string_on_eq_lhs__ "${option_string}"
    arg_spec_key="$(dict_get_simple "${__parseargs_longopts__}" "${__parseargs_return_value__}")"
    if [ -z "${arg_spec_key}" ]; then
      __parseargs_error_exit__ "Unknown long option --${__parseargs_return_value__}."
    fi
    shift
    __parseargs_split_string_on_eq_rhs__ "${option_string}"
    if [ "${__parseargs_return_value__}" !=  "${option_string}" ]; then
      set -- "${__parseargs_return_value__}" "$@"
    else
        __parseargs_shift_caller_args_by__=1
    fi
    __parseargs_process_argument_action__ "${arguments}" "${arg_spec_key}" "const" "Long option --${__parseargs_return_value__}" "$@"
  }

  __parseargs_parse_positional_argument__() {
    __parseargs_return_value__="${1}"
    local current_positional="${2}"
    shift 2
    local arg_spec_key="$(dict_get_simple "${__parseargs_positionals__}" "${current_positional}")"
    if [ -z "${arg_spec_key}" ]; then
      __parseargs_warn_continue__ "Too many positional arguments provided, remaining ignored."
      __parseargs_shift_caller_args_by__=0
      return
    fi
    __parseargs_process_argument_action__ "${__parseargs_return_value__}" "${arg_spec_key}" "default" "Positional #$(( ${current_positional}+1 )), '${arg_spec_key}'," "$@" 
  }

  __parseargs_extend_argument_index__='0'
  __parseargs_extend_argument__() {
      local argument="${1}"
      local value="${2}"
      if dict_is_dict "${value}"; then
        __parseargs_return_value__="${argument}"
        __parseargs_extend_argument_index__="$(dict_size "${existing_argument}" "${dest}" )"
        dict_for_each "${value}" '__parseargs_extend_dict_fn__'
      else
        local next_index="$(dict_size "${existing_argument}" "${dest}" )"
        __parseargs_return_value__="$(dict_set_simple "${argument}" "${next_index}" "${value}" )"
      fi
  }

  __parseargs_extend_dict_fn__() {
    local value="${2}"
    __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" "${__parseargs_extend_argument_index__}" "${value}")"
    __parseargs_extend_argument_index__=$(( ${__parseargs_extend_argument_index__}+1 ))
  }

  __parseargs_process_argument_action__() {
    local arguments="${1}"
    local arg_spec_key="${2}"
    local missing_arg_key="${3}"
    local arg_desc="${4}"
    shift 4
#echo "> PROCESS ARGS (${arg_desc}; args='$*', count=$#):" >&2
    local attributes="$(dict_get "${__parseargs_arg_specs__}" "${arg_spec_key}")"
    if [ -z "${attributes}" ]; then
      __parseargs_error_exit__ "(internal). ${arg_desc}: no attrubutes specifying this argument."
    fi
    local action="$(dict_get_simple "${attributes}" "action" )"
    local dest="$(dict_get_simple "${attributes}" "destination" )"
#echo "  dest:${dest}; shift by:${__parseargs_shift_caller_args_by__}; attributes:${attributes}; missing_arg_key:${missing_arg_key}" >&2
    case "${action}" in
      store)
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        ;;
      append)
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        local existing_argument="$(dict_get "${arguments}" "${dest}" )"
        if [ -z "${existing_argument}" ]; then
          existing_argument="$(dict_declare_simple)"
        fi
        local next_index="$(dict_size "${existing_argument}" "${dest}" )"
        __parseargs_return_value__="$(dict_set "${existing_argument}" "${next_index}" "${__parseargs_return_value__}" )"
        ;;
      extend)
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        local existing_argument="$(dict_get "${arguments}" "${dest}" )"
        if [ -z "${existing_argument}" ]; then
          existing_argument="$(dict_declare_simple)"
        fi
        __parseargs_extend_argument__ "${existing_argument}" "${__parseargs_return_value__}"
        ;;
      store_const)
        __parseargs_return_value__="$(dict_get_simple "${attributes}" "const" )"
        ;;
      append_const)
        local value="$(dict_get_simple "${attributes}" "const" )"
        local existing_argument="$(dict_get "${arguments}" "${dest}" )"
        if [ -z "${existing_argument}" ]; then
          existing_argument="$(dict_declare_simple)"
        fi
        local next_index="$(dict_size "${existing_argument}" "${dest}" )"
        __parseargs_return_value__="$(dict_set_simple "${existing_argument}" "${next_index}" "${value}" )"
        ;;
      store_true)
        __parseargs_return_value__='true'
        ;;
      store_false)
        __parseargs_return_value__='false'
        ;;
      count)
        local existing_argument="$(dict_get "${arguments}" "${dest}" )"
        if [ -z "${existing_argument}" ]; then
          existing_argument="0"
        fi
        __parseargs_return_value__="$(( ${existing_argument}+1 ))"
        ;;
      sub_argument)
        local entry_shift_caller_args_by="${__parseargs_shift_caller_args_by__}"
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        if [ "$(( ${__parseargs_shift_caller_args_by__}-${entry_shift_caller_args_by} ))" -eq '1' ]; then
          shift
          local sp_id="${__parseargs_return_value__}"
          local sp_alias="${sp_id}"
          local sub_parser="$(dict_get "${__parseargs_subparsers__}" "${sp_id}" )"
          if [ -z "${sub_parser}" ]; then
            sp_id="$(dict_get_simple "${__parseargs_subparser_alias__}" "${sp_alias}" )"
            if [ -n "${sp_id}" ]; then
              sub_parser="$(dict_get "${__parseargs_subparsers__}" "${sp_id}" )"
            fi
          fi
          if [ -z "${sub_parser}" ]; then
            __parseargs_error_exit__ "${arg_desc}: "${__parseargs_return_value__}" is not a known sub-command."
          fi

#echo "  >>>>>>>>>>>>>>>>>>>>>>>>> SUB PARSE for ${dest} START >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" >&2
          local sub_args="$(dict_get "${arguments}" "${dest}")"
#echo "  >>> Entry sub-arguments: ${sub_args} " >&2
          if [ -z "${sub_args}" ]; then
            sub_args="$(dict_declare_simple)"
          fi
          local outer_shift_by=${__parseargs_shift_caller_args_by__}
          local outer_current_positional=${__parseargs_current_positional__}
          local outer_arg_specs="${__parseargs_arg_specs__}"
          local outer_positionals="${__parseargs_positionals__}"
          local outer_longopts="${__parseargs_longopts__}"
          local outer_shortopts="${__parseargs_shortopts__}"
          local outer_optstring="${__parseargs_optstring__}"
          local outer_subparsers="${__parseargs_subparsers__}"
          local outer_sp_alias="${__parseargs_subparser_alias__}"

          __parseargs_set_parse_specs__ "${sub_parser}"
          __parseargs_current_positional__="$(dict_get_simple "${sub_args}" '__sub_argument_curpos__')"
          if [ -z "${__parseargs_current_positional__}" ]; then
            __parseargs_current_positional__=0
          fi
          local positionals_to_parse=true
          local expected_number_of_positionals="$(dict_size "${__parseargs_positionals__}")"
          if [ "${__parseargs_current_positional__}" -gt "${expected_number_of_positionals}" ]; then
            positionals_to_parse=false
          fi

          __parseargs_parse_argument__ "${sub_args}" "${positionals_to_parse}" '?' "$@"

          if [ -z "${__parseargs_return_value__}" ]; then
            __parseargs_return_value__="$(dict_declare_simple)"
          fi
          __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_argument_curpos__' "${__parseargs_current_positional__}")"
          __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+${outer_shift_by} ))
          __parseargs_current_positional__=${outer_current_positional}
          __parseargs_arg_specs__="${outer_arg_specs}"
          __parseargs_positionals__="${outer_positionals}"
          __parseargs_longopts__="${outer_longopts}"
          __parseargs_shortopts__="${outer_shortopts}"
          __parseargs_optstring__="${outer_optstring}"
          __parseargs_subparsers__="${outer_subparsers}"
          __parseargs_subparser_alias__="${outer_sp_alias}"
#echo "  >>> Return sub-arguments: ${__parseargs_return_value__} " >&2
#echo "  <<<<<<<<<<<<<<<<<<<<<<<<< SUB PARSE for ${dest} END   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >&2

          __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_command__' "${sp_id}" )"
          __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_command_alias__' "${sp_alias}" )"
        else
          __parseargs_error_exit__ "${arg_desc} did not have a single sub-argument command argument value."
        fi
        ;;
      sub_command)
        local entry_shift_caller_args_by="${__parseargs_shift_caller_args_by__}"
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        if [ "$(( ${__parseargs_shift_caller_args_by__}-${entry_shift_caller_args_by} ))" -eq '1' ]; then
          shift
          local sp_id="${__parseargs_return_value__}"
          local sp_alias="${sp_id}"
          local sub_parser="$(dict_get "${__parseargs_subparsers__}" "${sp_id}" )"
          if [ -z "${sub_parser}" ]; then
            sp_id="$(dict_get_simple "${__parseargs_subparser_alias__}" "${sp_alias}" )"
            if [ -n "${sp_id}" ]; then
              sub_parser="$(dict_get "${__parseargs_subparsers__}" "${sp_id}" )"
            fi
          fi
          if [ -z "${sub_parser}" ]; then
            __parseargs_error_exit__ "${arg_desc}: "${__parseargs_return_value__}" is not a known sub-command."
          fi

#echo "  >>>>>>>>>>>>>>>>>>>>>>>>> SUB PARSE for ${dest} START >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" >&2
          local outer_shift_by=$(( ${__parseargs_shift_caller_args_by__}+${#} ))
          local outer_current_positional=${__parseargs_current_positional__}
          __parseargs_parse_arguments__ "${sub_parser}" "$@"
          __parseargs_shift_caller_args_by__=${outer_shift_by}
          __parseargs_current_positional__=${outer_current_positional}
#echo "  <<<<<<<<<<<<<<<<<<<<<<<<< SUB PARSE for ${dest} END   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >&2

          if [ -z "${__parseargs_return_value__}" ]; then
            __parseargs_return_value__="$(dict_declare_simple)"
          fi
          __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_command__' "${sp_id}" )"
          __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_command_alias__' "${sp_alias}" )"
        else
          __parseargs_error_exit__ "${arg_desc} did not have a single sub-command command argument value."
        fi
        ;;
      *)
        __parseargs_error_exit__ "(internal) Unexpected unrecognised action '${action}'"
        ;;
      esac
      __parseargs_return_value__="$(dict_set "${arguments}" "${dest}" "${__parseargs_return_value__}")"
  }

  __parseargs_get_arguments__() {
    local attributes="${1}"
    local missing_arg_key="${2}"
    local arg_desc="${3}"
    shift 3
    if [ $# -gt 0 ] && [ -z "$*" ]; then
      # if all remaining arguments empty, consume them
      shift $#
    fi

    local nargs="$(dict_get_simple "${attributes}" "nargs" )"
    local missing_arg_value="-"
    
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
      __parseargs_get_argument__ "${on_missing}" "${missing_arg_value}" "${arg_desc}" "$@"
#echo "  Returning: shift by:${__parseargs_shift_caller_args_by__}; value:${__parseargs_return_value__}" >&2
#echo "< ADD ARGS(scalar)" >&2
      return
    fi

    local argument_list="$(dict_declare_simple)"
    local argument_index='0'
    local stashed_shift_caller_args_by="${__parseargs_shift_caller_args_by__}"
    local accumulated_shift_count="0"
    while [ "${nargs}" -ne "0" ]; do
      __parseargs_shift_caller_args_by__=0
      __parseargs_get_argument__ "${on_missing}" "${missing_arg_value}" "${arg_desc}" "$@"
      if [ -z "${__parseargs_return_value__}" ]; then
        break
      fi
      if [ "${on_missing}" = 'error_on_first' ]; then
        on_missing='break'
      fi
      argument_list="$(dict_set_simple "${argument_list}" "${argument_index}" "${__parseargs_return_value__}")"
      nargs="$(( ${nargs}-1 ))"
      argument_index="$(( ${argument_index}+1 ))"
      accumulated_shift_count="$(( ${accumulated_shift_count}+${__parseargs_shift_caller_args_by__} ))"
      shift "${__parseargs_shift_caller_args_by__}"
    done
    __parseargs_shift_caller_args_by__="$(( ${stashed_shift_caller_args_by}+${accumulated_shift_count} ))"
    __parseargs_return_value__="${argument_list}"
#echo "  Returning: shift by:${__parseargs_shift_caller_args_by__}; value:${__parseargs_return_value__}" >&2
#echo "< ADD ARGS(list ${argument_index}):" >&2
  }

  __parseargs_get_argument__() {
    local on_missing="${1}"
    local missing_arg_value="${2}"
    local arg_desc="${3}"
    shift 3
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
        __parseargs_return_value__="${arg_value}"
        __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+1 ))
        return
      fi
    fi
#echo "    Argument missing" >&2
    case "${on_missing}" in
      'value')
        __parseargs_return_value__="${missing_arg_value}"
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
    local arguments="${1}"
    __parseargs_return_value__="${arguments}"
    dict_for_each "${__parseargs_arg_specs__}" \
                  "__parseargs_op_validate_and_fixup_argument__" \
                  "${__parseargs_positionals__}" \
                  "${__parseargs_shortopts__}" \
                  "${__parseargs_longopts__}"
  }

  __parseargs_op_validate_and_fixup_argument__() {
    local arg_spec="${2}"
    local record_number="${3}"
    local positionals="${4}"
    local shortopts="${5}"
    local longopts="${6}"
    local arguments="${__parseargs_return_value__}"
    local dest="$(dict_get_simple "${arg_spec}" "destination" )"
    local arg="$(dict_get "${arguments}" "${dest}")"
    if [ -z "${arg}" ]; then
      local default="$(dict_get_simple "${arg_spec}" "default")"
      if [ -n "${default}" ]; then
        arguments="$(dict_set_simple "${arguments}" "${dest}" "${default}")"
      else
        local required="$(dict_get_simple "${arg_spec}" "required")"
        if [ -n "${required}" ] && "${required}"; then
          __parseargs_get_option_name__ "${arg_spec}"
          local optname="${__parseargs_return_value__}"
          __parseargs_error_exit__ "Required option ${optname} was not provided."
        fi
      fi
    fi
    local choices="$(dict_get "${arg_spec}" "choices")"
    if [ -n "${choices}" ]; then
      if dict_is_dict "${arg}"; then
        dict_for_each "${arg}" "__parseargs_op_check_value_valid_choice__" "${choices}" "${arg_spec}" "${positionals}"
      else
        __parseargs_op_check_value_valid_choice__ '_' "${arg}" '_' "${choices}" "${arg_spec}" "${positionals}"
      fi
    fi
    __parseargs_return_value__="${arguments}"
  }

  __parseargs_op_check_value_valid_choice__() {
    local value="${2}"
    local choices="${4}"
    local arg_spec="${5}"
    local positionals="${6}"
    local chosen="$(dict_get "${choices}" "${value}")"
    if [ -z "${chosen}" ]; then
      __parseargs_get_option_name__ "${arg_spec}"
      local optname="${__parseargs_return_value__}"
      if [ -z "${optname}" ]; then
        local i='0'
        local end="$(dict_size "${positionals}")"
        local dest="$(dict_get_simple "${arg_spec}" "destination")"
        while [ "${i}" -lt "${end}" ]; do
          local dest_i="$(dict_get_simple "${positionals}" "${i}")"
          if [ "${dest_i}" = "${dest}${i}" ]; then
            optname="positional argument #${i}"
            break
          fi
          i=$(( ${i}+1 ))
        done
      else
        optname="option ${optname}"
      fi
      __parseargs_error_exit__ "Value '${value}' is not a valid choice for ${optname}."
    fi
  }

  __parseargs_get_option_name__() {
    local arg_spec="${1}"
    local optname="$(dict_get_simple "${arg_spec}" "long")"
    if [ -z "${optname}" ]; then
      optname="$(dict_get_simple "${arg_spec}" "short")"
      if [ -n "${optname}" ]; then
        optname="-${optname}"
      fi
    else
      optname="--${optname}"
    fi
    __parseargs_return_value__="${optname}"
  }

fi

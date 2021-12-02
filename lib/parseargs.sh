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
    local parser="$(dict_declare \
                     "__PARSEARG_TYPE__" "argument_parser" \
                    "__arguments__" "${empty_dict}"  \
                    "__positionals__" "${empty_dict}" \
                    "__longopts__" "${empty_dict}"  \
                    "__shortopts__" "${empty_dict}"  \
                    "__subparsers__" "${empty_dict}" \
                    "__sp_aliases__" "${empty_dict}" \
                    "__optstring__" ":" \
                  )"
    local need_prog=true
    local add_help=true
    while [ "$#" -gt "1" ]; do
      case ${1} in
        argument_default)
          parser="$(dict_set_simple "${parser}" "argument_default" "${2}")"
          have_arg_default=true
          ;;
        prog)
          parser="$(dict_set_simple "${parser}" "prog" "${2}")"
          need_prog=false
          ;;
        usage)
          parser="$(dict_set_simple "${parser}" "usage" "${2}")"
          ;;
        description)
          parser="$(dict_set_simple "${parser}" "description" "${2}")"
          ;;
        epilogue)
          parser="$(dict_set_simple "${parser}" "epilogue" "${2}")"
          ;;
        add_help)
          if ! "${2}"; then
            add_help=false
          fi
          ;;
        *)
          __parseargs_error_exit__ "Unrecognised parser attribute '${1}'."
          ;;
      esac
      shift 2
    done
    if "${need_prog}"; then
      parser="$(dict_set_simple "${parser}" "prog" "${0}")"
    fi

    if "${add_help}"; then
      parser="$( parseargs_add_argument "${parser}" 'short' 'h' 'long' 'help' 'action' 'help' 'help' 'show this help message and exit' 2>&1)"
      if ! parseargs_is_argument_parser "${parser}"; then
        __parseargs_error_exit__ "Failed to add help optional argument to new parser: ${parser}"
      fi
    fi

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
    local help=''
    local metavar=''
    local version=''
    local have_default=false
    local have_const=false
    local have_required=false
    local have_choices=false
    local storing_something=true
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
          if ! __parseargs_is_valid_nargs_value__ "${num_args}" "${__PARSEARGS_MAX_NARGS__}"; then
          echo "nargs value '${num_args}' invalid. Must be integer in the range [1, ${__PARSEARGS_MAX_NARGS__}], '?','*' or '+'." >&2
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
          ;;
        version)
          __parseargs_abort_if_have_attribute_value__ "${version}" 'version'
          version="${2}"
          ;;
        help)
          __parseargs_abort_if_have_attribute_value__ "${help}" 'help'
          help="${2}"
          ;;
        metavar)
          __parseargs_abort_if_have_attribute_value__ "${metavar}" 'metavar'
          metavar="${2}"
          ;;
        *)
          __parseargs_error_exit__ "Unrecognised parser argument attribute '${1}'."
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

    if [ -z "${action}" ]; then
      if [ -n "${version}" ]; then
        action="version"
      else
        action="store"
      fi
    fi

    if [ -n "${version}" ]; then
      if [ "${action}" != 'version' ]; then
        __parseargs_warn_continue__ "'version' attribute provided for argument with non 'version' action (action is '${action})'."
      elif [ -z "${dest}" ]; then
        dest='version'
      fi
    fi

    local argument_key="${dest}"

    if [ -z "${dest}" ]; then
      __parseargs_error_exit__ "Unable to deduce destination name for argument value from destination, name or long attribute values."
    fi

    if [ -n "${positional}" ]; then

      if [ "${action}" != 'store' ] && [ "${action}" != 'sub_command' ]; then
        __parseargs_error_exit__ "Action attribute value '${action}' cannot be used for positional arguments '${dest}'."
      fi
      if [ "${num_args}" = '?' ] && ! ${have_default}; then
        local global_default="$(dict_get_simple "${parser}" 'argument_default')"
#echo "positional argument with nargs of '?' (0|1) with no per-argument default, using parser global default of : '${global_default}'." >&2
          if [ -n "${global_default}" ]; then
          have_default=true
          argument="$(dict_set_simple "${argument}" "default" "${global_default}")"
        else
          __parseargs_error_exit__ "A default attribute value is required for optional positional argument (nargs=?) '${dest}'."
        fi
      fi
      argument="$(dict_set_simple "${argument}" "name" "${2}")"
      positionals="$(dict_get "${parser}" "__positionals__")"
      local pos_id="$(dict_size "${positionals}")"
      argument_key="${argument_key}${pos_id}"
      positionals="$(dict_set_simple "${positionals}" "${pos_id}" "${argument_key}")"
    elif  [ -n "${is_option}" ]; then
      if [ "${num_args}" = '?' ] && ! ${have_const}; then
        __parseargs_error_exit__ "A const attribute value is required for optional arguments with optional value (nargs=?) '${dest}'."
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
        optstring="${optstring}${short_opt}"
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

    case "${action}" in
      store|append|extend)
        if [ -n "${short_opt}" ]; then
          optstring="${optstring}:"
        fi
        ;;
      sub_command | sub_argument)
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'sub_command' or 'sub_argument' action attributes '${dest}'."
        fi
        if "${have_const}"; then
          __parseargs_error_exit__ "Cannot specify a const attribute value for arguments with 'sub_command' or 'sub_argument' action attributes '${dest}'."
        fi
        if [ -n "${short_opt}" ]; then
          optstring="${optstring}:"
        fi
        ;;
      store_const|append_const)
        if ! "${have_const}"; then
          __parseargs_error_exit__ "A const attribute value is required for arguments with 'store_const' or 'append_const' action attribute '${dest}'."
        fi
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'store_const' or 'append_const' action attribute '${dest}'."
        fi
        num_args=0
        ;;
      store_true|store_false)
        if "${have_default}" || "${have_const}"; then
          __parseargs_error_exit__ "Cannot specify a default or const attribute value for arguments with 'store_true' or 'store_false' action attributes '${dest}'."
        fi
        if [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify nargs attribute value for arguments with 'store_true' or 'store_false' action attributes '${dest}'."
        fi
        num_args=0
        have_default=true
        if [ "${action}" = 'store_true' ]; then
          argument="$(dict_set_simple "${argument}" "default" false)"
        else
          argument="$(dict_set_simple "${argument}" "default" true)"
        fi
        ;;
      count)
        if "${have_const}" || [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify a const or nargs attribute value for arguments with 'count' action attribute '${dest}'."
        fi
        num_args=0
        ;;
      version)
        if [ -z "${version}" ]; then
          __parseargs_error_exit__ "A version attribute with a value supplying the version text is required for arguments with 'version' action attribute '${dest}'."
        fi
        if "${have_default}" || "${have_const}" || "${have_required}" || "${have_choices}" || [ -n "${num_args}" ]; then
          __parseargs_error_exit__ "Cannot specify const, default, required, choices or nargs attribute values for 'version' action attributes '${dest}'."
        fi
        argument="$(dict_set_simple "${argument}" "version" "${version}")"
        storing_something=false
        num_args=0
        ;;
      help)
        if "${have_default}" || "${have_const}" || "${have_required}" || "${have_choices}" || [ -n "${num_args}" ] || [ -n "${version}" ]; then
          __parseargs_error_exit__ "Cannot specify const, default, required, choices, version or nargs attribute values for 'help' action attributes '${dest}'."
        fi
        storing_something=false
        num_args=0
        ;;
      *)
        __parseargs_error_exit__ "Unrecognised action attribute value '${action}' for argument '${dest}'."
        ;;
    esac
    if [ -n "${num_args}" ]; then
      argument="$(dict_set_simple "${argument}" "nargs" "${num_args}")"
    fi
    argument="$(dict_set_simple "${argument}" "action" "${action}")"
    if [ -n "${help}" ]; then
      argument="$(dict_set_simple "${argument}" "help" "${help}")"
    fi
    if [ -n "${metavar}" ]; then
      if dict_is_dict "${metavar}"; then
        if [ "$(dict_size "${metavar}")" -ne "${num_args}"  ]; then
          __parseargs_error_exit__ "Number of metavar values does not match number of arguments (nargs=${num_args}) for argument '${dest}'."
        fi
      fi
      argument="$(dict_set "${argument}" "metavar" "${metavar}")"
    fi

    if "${storing_something}"; then
      argument="$(dict_set_simple "${argument}" "destination" "${dest}")"
      if ! "${have_default}"; then
        local global_default="$(dict_get_simple "${parser}" 'argument_default')"
        if [ -n "${global_default}" ]; then
  #echo "Argument has no specified default, using default value of: '${global_default}'." >&2
          have_default=true
          argument="$(dict_set_simple "${argument}" "default" "${global_default}")"
        fi
      fi
    fi

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
    if ! parseargs_is_argument_parser "${4}"; then
      __parseargs_error_exit__ "Forth (sub-parser) argument passed to parseargs_add_sub_parser is not an argument parser type. Quitting current (sub-)shell."
    fi
    local parser="${1}"
    local arg_dest="${2}"
    local subparser_id="${3}"
    local subparser="${4}"
    shift 4
    local subparsers="$(dict_get "${parser}" "__subparsers__")"
    if [ -z "${subparsers}" ]; then
      subparsers="$(dict_declare_simple)"
    fi
    local arg_subparsers="$(dict_get "${subparsers}" "${arg_dest}")"
    if [ -z "${arg_subparsers}" ]; then
      arg_subparsers="$(dict_declare_simple)"
    fi
    arg_subparsers="$(dict_set "${arg_subparsers}" "${subparser_id}" "${subparser}")"
    subparsers="$(dict_set "${subparsers}" "${arg_dest}" "${arg_subparsers}")"
    parser="$(dict_set "${parser}" "__subparsers__" "${subparsers}")"

    if [ "$#" -gt "0" ]; then
      local aliases="$(dict_get "${parser}" "__sp_aliases__")"
      if [ -z "${aliases}" ]; then
        aliases="$(dict_declare_simple)"
      fi
      local arg_aliases="$(dict_get "${aliases}" "${arg_dest}")"
      if [ -z "${arg_aliases}" ]; then
        arg_aliases="$(dict_declare_simple)"
      fi
      while [ "$#" -gt "0" ]; do
        arg_aliases="$(dict_set_simple "${arg_aliases}" "${1}" "${subparser_id}")"
        shift
      done
      aliases="$(dict_set "${aliases}" "${arg_dest}" "${arg_aliases}")"
      parser="$(dict_set "${parser}" "__sp_aliases__" "${aliases}")"
    fi
    echo -n "${parser}"
  }

  parseargs_parse_arguments() {
    __parseargs_parse_arguments__ "$@"
#echo "arguments before validation/fixup:'${__parseargs_return_value__}'." >&2
  __parseargs_validate_and_fixup_arguments__ "${__parseargs_return_value__}"
#echo "arguments  after validation/fixup:'${__parseargs_return_value__}'." >&2
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
    __parseargs_parser__="${1}"
    __parseargs_arg_specs__="$(dict_get "${__parseargs_parser__}" "__arguments__")"
    __parseargs_positionals__="$(dict_get "${__parseargs_parser__}" "__positionals__")"
    __parseargs_longopts__="$(dict_get "${__parseargs_parser__}" "__longopts__")"
    __parseargs_shortopts__="$(dict_get "${__parseargs_parser__}" "__shortopts__")"
    __parseargs_optstring__="$(dict_get_simple "${__parseargs_parser__}" "__optstring__")"
    __parseargs_subparsers__="$(dict_get "${__parseargs_parser__}" "__subparsers__")"
    __parseargs_subparser_alias__="$(dict_get "${__parseargs_parser__}" "__sp_aliases__")"    
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

  __parseargs_sub_context_around() {
    local function="${1}"
    shift

    local outer_current_positional=${__parseargs_current_positional__}
    local outer_parser="${__parseargs_parser__}"
    local outer_arg_specs="${__parseargs_arg_specs__}"
    local outer_positionals="${__parseargs_positionals__}"
    local outer_longopts="${__parseargs_longopts__}"
    local outer_shortopts="${__parseargs_shortopts__}"
    local outer_optstring="${__parseargs_optstring__}"
    local outer_subparsers="${__parseargs_subparsers__}"
    local outer_sp_alias="${__parseargs_subparser_alias__}"

    ${function} "$@"

    __parseargs_current_positional__=${outer_current_positional}
    __parseargs_parser__="${outer_parser}"
    __parseargs_arg_specs__="${outer_arg_specs}"
    __parseargs_positionals__="${outer_positionals}"
    __parseargs_longopts__="${outer_longopts}"
    __parseargs_shortopts__="${outer_shortopts}"
    __parseargs_optstring__="${outer_optstring}"
    __parseargs_subparsers__="${outer_subparsers}"
    __parseargs_subparser_alias__="${outer_sp_alias}"
  }

  __parseargs_parse_arguments__() {
    __parseargs_abort_if_not_parser__ "${1}" "parseargs_parse_arguments"
    local parser="${1}"
    __parseargs_set_parse_specs__ "${parser}"
    __parseargs_current_positional__="0"
    local positionals_to_parse=true

  # return value is a dict containing the parsed aguments
    __parseargs_return_value__="$(dict_declare_simple)"
    shift
    local expected_number_of_positionals="$(dict_size "${__parseargs_positionals__}")"
#echo "OPTSTRING:'${optstring}'." >&2
#echo "Expected number of positional (start args): ${expected_number_of_positionals}" >&2
    while [ "$#" -gt "0" ]; do
        if [ "${__parseargs_current_positional__}" -gt "${expected_number_of_positionals}" ]; then
          positionals_to_parse=false
        fi
        __parseargs_parse_argument__ "${__parseargs_return_value__}" "${positionals_to_parse}" '*' "$@"
        shift ${__parseargs_shift_caller_args_by__}
    done
#echo "Expected number of positional (end args): ${expected_number_of_positionals}, current positional: ${__parseargs_current_positional__}" >&2
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
        __parseargs_extend_argument_index__="$(dict_size "${argument}" "${dest}" )"
        dict_for_each "${value}" '__parseargs_extend_dict_fn__'
      else
        local next_index="$(dict_size "${argument}" "${dest}" )"
        __parseargs_return_value__="$(dict_set_simple "${argument}" "${next_index}" "${value}" )"
      fi
  }

  __parseargs_extend_dict_fn__() {
    local value="${2}"
    __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" "${__parseargs_extend_argument_index__}" "${value}")"
    __parseargs_extend_argument_index__=$(( ${__parseargs_extend_argument_index__}+1 ))
  }

  __parseargs_sub_argument_sub_parse__()
  {
    local sub_parser="${1}"
    local sub_args="${2}"
    shift 2
    __parseargs_set_parse_specs__ "${sub_parser}"
    __parseargs_current_positional__="$(dict_get_simple "${sub_args}" '__sub_curpos__')"
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
    __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_curpos__' "${__parseargs_current_positional__}")"
   }

  __parseargs_sub_command_sub_parse__()
  {
    local sub_parser="${1}"
    shift
    __parseargs_parse_arguments__ "${sub_parser}" "$@"
    if [ -z "${__parseargs_return_value__}" ]; then
      __parseargs_return_value__="$(dict_declare_simple)"
    fi
    __parseargs_return_value__="$(dict_set_simple "${__parseargs_return_value__}" '__sub_curpos__' "${__parseargs_current_positional__}")"
  }

  __parseargs_sub_parse_and_store__() {
    local sub_parse_fn="${1}"
    local sp_id="${2}"
    local dest="${3}"
    local arg_desc="${4}"
    local store_parser=''
    local sp_alias="${sp_id}"

    local sub_parser=''
    local arg_sub_parsers="$(dict_get "${__parseargs_subparsers__}" "${dest}" )"
    if [ -n "${arg_sub_parsers}" ]; then
      sub_parser="$(dict_get "${arg_sub_parsers}" "${sp_id}" )"
      if [ -z "${sub_parser}" ]; then
        arg_sp_aliases="$(dict_get "${__parseargs_subparser_alias__}" "${dest}" )"
        if [ -n "${arg_sp_aliases}" ]; then
          sp_id="$(dict_get_simple "${arg_sp_aliases}" "${sp_alias}" )"
          if [ -n "${sp_id}" ]; then
            sub_parser="$(dict_get "${arg_sub_parsers}" "${sp_id}" )"
          fi
        fi
      fi
    fi
    if [ -z "${sub_parser}" ]; then
      __parseargs_error_exit__ "${arg_desc}: "${sp_alias}" is not a known sub-command."
    fi
    if dict_is_dict "${5}"; then
      store_parser="${5}"
      shift 5
      local existing_args="$(dict_get "${sp_ids}" "${sp_id}")"
      if [ -z "${existing_args}" ]; then
        existing_args="$(dict_declare_simple)"
      fi
      set -- "${existing_args}" "$@"
    else
      shift 4
    fi
#echo "  >>>>>>>>>>>>>>>>>>>>>>>>> SUB PARSE for ${dest} START >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>" >&2
#echo "  >>> Entry sub-arguments: $@ " >&2
    __parseargs_sub_context_around "${sub_parse_fn}" "${sub_parser}" "$@"
#echo "  >>> Return sub-arguments: ${__parseargs_return_value__} " >&2          
#echo "  <<<<<<<<<<<<<<<<<<<<<<<<< SUB PARSE for ${dest} END   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<" >&2
    if [ -z "${store_parser}" ]; then
      __parseargs_return_value__="$(dict_declare "${sp_id}" "${__parseargs_return_value__}")"
    else
      __parseargs_return_value__="$(dict_set "${store_parser}" "${sp_id}" "${__parseargs_return_value__}")"
    fi
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
#echo "  dest:${dest}; action:${action} shift by:${__parseargs_shift_caller_args_by__}; attributes:${attributes}; missing_arg_key:${missing_arg_key}" >&2
    case "${action}" in
      version)
        local version_text="$(dict_get_simple "${attributes}" "version" )"
        echo "${version_text}"
        exit 0
        ;;
      help)
        __parseargs_build_help_string__
        echo "${__parseargs_return_value__}"
        exit 0
        ;;
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
  
          local sp_ids="$(dict_get "${arguments}" "${dest}")"
          if [ -z "${sp_ids}" ]; then
            sp_ids="$(dict_declare_simple)"
          fi

          local outer_shift_by=${__parseargs_shift_caller_args_by__}
          local sp_id="${__parseargs_return_value__}"
          __parseargs_sub_parse_and_store__ '__parseargs_sub_argument_sub_parse__' "${sp_id}" "${dest}" "${arg_desc}" "${sp_ids}" "$@"
          __parseargs_shift_caller_args_by__=$(( ${__parseargs_shift_caller_args_by__}+${outer_shift_by} ))
        else
          __parseargs_error_exit__ "${arg_desc} did not have a single sub-argument command argument value."
        fi
        ;;
      sub_command)
        local entry_shift_caller_args_by="${__parseargs_shift_caller_args_by__}"
        __parseargs_get_arguments__ "${attributes}" "${missing_arg_key}" "${arg_desc}" "$@"
        if [ "$(( ${__parseargs_shift_caller_args_by__}-${entry_shift_caller_args_by} ))" -eq '1' ]; then
          shift
          local outer_shift_by=$(( ${__parseargs_shift_caller_args_by__}+${#} ))
          local sp_id="${__parseargs_return_value__}"
          __parseargs_sub_parse_and_store__ '__parseargs_sub_command_sub_parse__' "${sp_id}" "${dest}" "${arg_desc}" "$@"
          __parseargs_shift_caller_args_by__=${outer_shift_by}
        else
          __parseargs_error_exit__ "${arg_desc} did not have a single sub-command command argument value."
        fi
        ;;
      *)
        __parseargs_error_exit__ "(internal) Unexpected unrecognised action '${action}'"
        ;;
      esac
    __parseargs_return_value__="$(dict_set "${arguments}" "${dest}" "${__parseargs_return_value__}")"
#echo ">>> Returned arguments: ${__parseargs_return_value__} " >&2          
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
      local missing_arg_value="$(dict_get_simple "${attributes}" "${missing_arg_key}" )"
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

  __parseargs_build_help_string__() {
    local usage="$(dict_get_simple "${__parseargs_parser__}" 'usage')"
    if [ -n "${usage}" ]; then
      local deduce_usage=false
    else
      local deduce_usage=true
    fi
    __parseargs_return_value__="$(dict_declare_simple)"
    dict_for_each "${__parseargs_arg_specs__}" \
                  "__parseargs_op_build_argument_help__" \
                  "${deduce_usage}"
    if "${deduce_usage}"; then
      local usage="$(dict_get_simple "${__parseargs_return_value__}" 'uopts') $(dict_get_simple "${__parseargs_return_value__}" 'uposits')"
    fi

    local desc="$(dict_get_simple "${__parseargs_parser__}" 'description')"
    local epi="$(dict_get_simple "${__parseargs_parser__}" 'epilogue')"
    local posits="$(dict_get_simple "${__parseargs_return_value__}" 'posits')"
    local opts="$(dict_get_simple "${__parseargs_return_value__}" 'opts')"
    local prog="$(dict_get_simple "${__parseargs_parser__}" 'prog')"
    local help="usage: ${prog} ${usage}\n"
    if "${deduce_usage}"; then
      __parseargs_help_wrap_and_fill_append__ "${help}" '' "         " 80 80 0 20
      help="${__parseargs_return_value__}\n"
    fi
    if [ -n "${desc}" ]; then
      help="${help}\n${desc}\n"
    fi
    if [ -n "${posits}" ]; then
      help="${help}\npositional arguments:\n${posits}"
    fi
    if [ -n "${opts}" ]; then
      help="${help}\noptional arguments:\n${opts}"
    fi
    if [ -n "${epi}" ]; then
      help="${help}\n${epi}\n"
    fi
    __parseargs_return_value__="${help}"
  }

  __parseargs_op_build_argument_help__() {
    local arg_spec="${2}"
    local record_number="${3}"
    local deduce_usage="${4}"
    local arg_desc="$(dict_get_simple "${arg_spec}" "help" )"
    local arg_depiction="$(dict_get "${arg_spec}" "metavar" )"
    if [ -z "${arg_depiction}" ]; then
      arg_depiction="$(dict_get_simple "${arg_spec}" "destination" )"
    fi
    local nargs="$(dict_get_simple "${arg_spec}" "nargs" )"
    local required="$(dict_get_simple "${arg_spec}" "required")"
    local saved_return_value="${__parseargs_return_value__}"
    __parseargs_help_wrap_and_fill_append__ "${arg_desc}" '' "                         " 25 80 25 20
    arg_desc="${__parseargs_return_value__}"
    __parseargs_make_argument_help_string__ "${arg_depiction}" "${nargs}"
    arg_depiction="${__parseargs_return_value__}"
    __parseargs_return_value__="${saved_return_value}"
    local opt="$(dict_get_simple "${arg_spec}" "short" )"
    local optl="$(dict_get_simple "${arg_spec}" "long" )"
#echo "arg_desc:'${arg_desc}'  opt: '${opt}'  optl:'${optl}' arg_depiction:'${arg_depiction}' arg_spec:'${arg_spec}'" >&2
    if [ -n "${opt}" ] || [ -n "${optl}" ]; then
      local arg_help='  '
      local maybe_comma=''
      if [ -n "${opt}" ]; then
        opt="-${opt} ${arg_depiction}"
        arg_help="${arg_help}${opt}"
        maybe_comma=', '
      fi
      if [ -n "${optl}" ]; then
        optl="--${optl} ${arg_depiction}"
        arg_help="${arg_help}${maybe_comma}${optl}"
        if [ -z "${opt}" ]; then
          opt="${optl}"
        fi
      fi
      __parseargs_help_arg_help_and_deduced_usage__ "${arg_help}" 'opts' 'uopts' "${opt}" "${required}"
    else # positional argument...
      __parseargs_help_arg_help_and_deduced_usage__ "${arg_depiction}" 'posits' 'uposits' "${arg_depiction}"
    fi
  }

  __parseargs_help_arg_help_and_deduced_usage__()
  {
    local arg_help="${1}"
    local arg_type="${2}"
    local usage_type=''
    local arg_usage=''
    local required=''
    if [ $# -ge 4 ]; then
      usage_type="${3}"
      arg_usage="${4}"
      if [ $# -ge 5 ]; then
        required="${5}"
      fi
    fi
    saved_return_value="${__parseargs_return_value__}"
    __parseargs_help_wrap_and_fill_append__ "${arg_help}" "${arg_desc}" "     " 25 80 0 20
    arg_help="${__parseargs_return_value__}\n"
  __parseargs_return_value__="${saved_return_value}"
    local arg_types_help="$(dict_get "${__parseargs_return_value__}" "${arg_type}" )"
#echo "arg_help:'${arg_help}' ${arg_type}:'${arg_types_help}'" >&2
    arg_types_help="${arg_types_help% }"
    arg_types_help="${arg_types_help}${arg_help} "
#echo "${arg_type} (updated):'${arg_types_help}'" >&2
    __parseargs_return_value__="$(dict_set "${__parseargs_return_value__}" "${arg_type}" "${arg_types_help}" )"
    if [ -n "${usage_type}" ]; then
      local usage="$(dict_get "${__parseargs_return_value__}" "${usage_type}" )"
      if [ -n "${usage}" ]; then
        usage="${usage} "
      fi
      if [ -n "${required}" ] && "${required}"; then
        usage="${usage}${arg_usage}"
      else
        usage="${usage}[${arg_usage}]"
      fi
      __parseargs_return_value__="$(dict_set "${__parseargs_return_value__}" "${usage_type}" "${usage}" )"
    fi
  }

  __parseargs_make_argument_help_string__() {
    local argname="${1}"
    local nargs="${2}"

    if dict_is_dict "${argname}"; then
      __parseargs_return_value__=''
      dict_for_each "${argname}" '__parseargs_op_make_argument_help_string__'
    else
      case "${nargs}" in
        0)
          __parseargs_return_value__=''
          ;;
        ''|1)
          __parseargs_return_value__="${argname}"
          ;;
        2)
          __parseargs_return_value__="${argname}-1 ${argname}-2"
          ;;
        3)
          __parseargs_return_value__="${argname}-1 ${argname}-2 ${argname}-3"
          ;;
        4)
          __parseargs_return_value__="${argname}-1 ${argname}-2 ${argname}-3 ${argname}-4"
          ;;
        '?')
          __parseargs_return_value__="[${argname}]"
          ;;
        '*')
          __parseargs_return_value__="[${argname}-1 [${argname}-2 ...]]"
          ;;
        '+')
          __parseargs_return_value__="${argname}-1 [${argname}-2 ...]"
          ;;
        *)
          __parseargs_return_value__="${argname}-1 ${argname}-2 ... ${argname}-${nargs}"
          ;;
      esac
    fi
  }

  __parseargs_op_make_argument_help_string__() {
    if [ -z "${__parseargs_return_value__}" ]; then
      __parseargs_return_value__="${1}"
    else
      __parseargs_return_value__="${__parseargs_return_value__} ${1}"
    fi
  }

  __parseargs_break_string_at_left_cached_pattern__=''
  __parseargs_break_string_at_index_left__() {
  # return ${1}[0, ${2}) 
  # i.e. up to but not including character at string index ${2}
    local string="${1}"
    local break_at_idx=${2} # zero based character index
    if [ ${break_at_idx} -le 0 ]; then
      __parseargs_return_value__=''
    elif [ ${break_at_idx} -ge "${#string}" ]; then
      __parseargs_return_value__="${string}"
    else
      local remove_len=$(( ${#string}-${break_at_idx} ))
      if [ ${#__parseargs_break_string_at_left_cached_pattern__} -ne ${remove_len} ]; then
        local count=0
        __parseargs_break_string_at_left_cached_pattern__=''
        while [ ${count} -lt ${remove_len} ]; do
          __parseargs_break_string_at_left_cached_pattern__="${__parseargs_break_string_at_left_cached_pattern__}?"
          count=$(( ${count}+1 ))
        done
      fi
      __parseargs_return_value__="${string%${__parseargs_break_string_at_left_cached_pattern__}}"
    fi
  }

  __parseargs_break_string_at_right_cached_pattern__=''
  __parseargs_break_string_at_index_right__() {
  # return ${1}[${2}, ${#1}) 
  # i.e. from and including character at string ${1} index ${2} to end of string
    local string="${1}"
    local break_at_idx=${2} # zero based character index
    if [ ${break_at_idx} -ge "${#string}" ]; then
      __parseargs_return_value__=''
    elif [ ${break_at_idx} -le 0 ]; then
      __parseargs_return_value__="${string}"
    else
      local remove_len=${break_at_idx}
      if [ ${#__parseargs_break_string_at_right_cached_pattern__} -ne ${remove_len} ]; then
        local count=0
        __parseargs_break_string_at_right_cached_pattern__=''
        while [ ${count} -lt ${remove_len} ]; do
          __parseargs_break_string_at_right_cached_pattern__="${__parseargs_break_string_at_right_cached_pattern__}?"
          count=$(( ${count}+1 ))
        done
      fi
      __parseargs_return_value__="${string#${__parseargs_break_string_at_right_cached_pattern__}}"
    fi
  }

  __parseargs_help_wrap_and_fill_append__() {
    local source_text="${1}"
    local append_text="${2}"
    local indent="${3}"
    local append_col=${4}
    local wrap_col=${5}
    local start_col="${6}"
    local max_word_len=${7}

    local out=''
    local len="${#source_text}"
    local break_col=$(( ${wrap_col}-${start_col} ))
    local word_break_part=''
    while [ $len -gt ${break_col} ]; do
#echo "out:'${out}'  source_text:'${source_text}'  len:${len}" >&2
      __parseargs_break_string_at_index_left__ "${source_text}" ${break_col}
      word_break_part="${__parseargs_return_value__##*' '}"
      if [ ${#word_break_part} -le ${max_word_len} ]; then
        out="${out}${__parseargs_return_value__%' '*}\n"
        break_col=$(( ${break_col}-${#word_break_part} ))
      else
        out="${out}${__parseargs_return_value__%' '*}\n"
      fi
      __parseargs_break_string_at_index_right__ "${source_text}" ${break_col}
      source_text="${indent}${__parseargs_return_value__}"
      len=$(( $len-${break_col}+${#indent} ))
      break_col=${wrap_col}
    done
    out="${out}${source_text}"
#echo "out:'${out}'  source_text:'${source_text}'  append_text:'${append_text}'  len:${len}" >&2
    if [ -n "${append_text}" ]; then
      if [ ${len} -ge ${append_col} ]; then
        out="${out}\n"
        local required_spaces=${append_col}
      else
        local required_spaces=$(( ${append_col}-${len} ))
      fi
      len=0
      while [ ${len} -lt ${required_spaces} ]; do
        out="${out} "
        len=$(( ${len}+1 ))
      done
      __parseargs_return_value__="${out}${append_text}"
    else
      __parseargs_return_value__="${out}"
    fi
  }

  __parseargs_check_for_missing_positionals__() {
    local expected_number_of_positionals="${1}"
#echo "check for missing positional: provided number: ${__parseargs_current_positional__}; expected number:'${expected_number_of_positionals}'." >&2

    while [ "${__parseargs_current_positional__}" -ne "${expected_number_of_positionals}" ]; do
      __parseargs_parse_positional_argument__ "${__parseargs_return_value__}" "${__parseargs_current_positional__}"
      __parseargs_current_positional__=$((${__parseargs_current_positional__}+1))
    done
  }

  __parseargs_validate_and_fixup_arguments__() {
    local arguments="${1}"
    __parseargs_return_value__="${arguments}"
    if [ -z "${arguments}" ]; then
      __parseargs_return_value__="$(dict_declare_simple)"
    else
      local expected_number_of_positionals="$(dict_size "${__parseargs_positionals__}")"
#echo "arguments before missing positionals check:'${__parseargs_return_value__}'." >&2
      __parseargs_check_for_missing_positionals__ "${expected_number_of_positionals}"
    fi
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
    local action="$(dict_get_simple "${arg_spec}" 'action')"
    if [ "${action}" = 'sub_command' ] || [ "${action}" = 'sub_argument' ]; then
      if [ -z "${arg}" ]; then
        arg="$(dict_declare_simple)"
      fi
#echo "  >>>>>>>>>>>>>>>>>>>>>>>>> VALIDATE & FIXUP FOR SUB COMMANDS for ${dest} START >>>>>>>>>>>>>>>>>>>>>>>>>" >&2
      __parseargs_return_value__="${arg}"
      if [ "${action}" = 'sub_command' ]; then
#echo "@@@ arg='${arg}'"       >&2
        dict_for_each "${arg}" '__parseargs_op_validate_and_fixup_sub_arguments__' 'subcmds' "${dest}"
      else
        local arg_sub_parsers="$(dict_get "${__parseargs_subparsers__}" "${dest}" )"
        if [ -n "${arg_sub_parsers}" ]; then
          dict_for_each "${arg_sub_parsers}" '__parseargs_op_validate_and_fixup_sub_arguments__' 'sp' '_'
        fi
      fi
      if [ "$(dict_size "${__parseargs_return_value__}")" -gt 0 ]; then
        arguments="$(dict_set "${arguments}" "${dest}" "${__parseargs_return_value__}")"
      else
        local required="$(dict_get_simple "${arg_spec}" "required")"
        if [ -n "${required}" ] && "${required}" && [ -z ]; then
          __parseargs_get_option_name__ "${arg_spec}"
          local optname="${__parseargs_return_value__}"
          __parseargs_error_exit__ "Required option ${optname} was not provided."
        fi
      fi
#echo "    Returned value: ${__parseargs_return_value__}" >&2
#echo "  >>>>>>>>>>>>>>>>>>>>>>>>>> VALIDATE & FIXUP FOR SUB COMMANDS for ${dest} END >>>>>>>>>>>>>>>>>>>>>>>>>>" >&2
    elif [ -z "${arg}" ]; then
#echo "'${dest}':<empty>" >&2
      local default="$(dict_get_simple "${arg_spec}" "default")"
#echo "'${dest}' has default '${default}'" >&2
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

  __parseargs_sub_parser_validate_and_fixup___()
  {
    local sub_parser="${1}"
    local arg="${2}"
    shift 2

    __parseargs_current_positional__='0'
    if dict_is_dict "${arg}"; then
      __parseargs_current_positional__="$(dict_get_simple "${arg}" '__sub_curpos__')"
#echo "      >>>>>>> ARG is DICT !!: __parseargs_current_positional__=${__parseargs_current_positional__}" >&2    
    fi
    __parseargs_set_parse_specs__ "${sub_parser}"
    __parseargs_validate_and_fixup_arguments__ "${arg}"
  }

  __parseargs_op_validate_and_fixup_sub_arguments__() {
    local sp_id="${1}"
    local sub_cmds="${__parseargs_return_value__}"
    if [ -z "${sp_id}" ]; then
      __parseargs_error_exit__ "(Internal) sub-command/sub_argument arguments for '${dest}' are missing the '__sub_command__' entry."
    fi
    local iterating_over="${4}"

#echo "      ==========================>> ITERATING OVER: '${iterating_over}'" >&2
    if [ "${iterating_over}" = 'sp' ]; then
      local sub_parser="${2}"
      local arg="$(dict_get "${sub_cmds}" "${sp_id}" )"
    else
      local dest="${5}"
      local arg_sub_parsers="$(dict_get "${__parseargs_subparsers__}" "${dest}" )"
      if [ -z "${arg_sub_parsers}" ]; then
        return
      fi
      local sub_parser="$(dict_get "${arg_sub_parsers}" "${sp_id}" )"
      local arg="${2}"
#echo "      ==========================>> Subparser for: '${dest}':'${sp_id}':  '${sub_parser}'" >&2      
    fi

    local rm_curpos=true
    if [ -z "${arg}" ]; then
#echo "      >>>>>>>>>>>>>>>>>>>>>>> NOT removing sub_curpos <<<<<<<<<<<<<<<<<<<<" >&2
      rm_curpos=false
    fi

#echo "      >>>>>>>>>>>>>>>>>>>>>>> VALIDATE & FIXUP FOR SUB ARGUMENTS for ${sp_id} START >>>>>>>>>>>>>>>>>>>>>>>" >&2
#echo "        subparser='${sub_parser}';  arguments='${arg}'" >&2
    __parseargs_sub_context_around '__parseargs_sub_parser_validate_and_fixup___' "${sub_parser}" "${arg}"

    if [ "$(dict_size "${__parseargs_return_value__}")" -gt 0 ]; then
      if $rm_curpos; then
        __parseargs_return_value__="$(dict_remove "${__parseargs_return_value__}" '__sub_curpos__')"
#echo "      >>>>>>>>>>>>>>>>>>>>>>> REMOVED sub_curpos <<<<<<<<<<<<<<<<<<<<" >&2
      fi
      __parseargs_return_value__="$(dict_set "${sub_cmds}" "${sp_id}" "${__parseargs_return_value__}")"
    else  
      __parseargs_return_value__="${sub_cmds}"
    fi
#echo "        return value: ${__parseargs_return_value__}" >&2
#echo "      >>>>>>>>>>>>>>>>>>>>>>> VALIDATE & FIXUP FOR SUB ARGUMENTS for ${sp_id}  END  >>>>>>>>>>>>>>>>>>>>>>>" >&2
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

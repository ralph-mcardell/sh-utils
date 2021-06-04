#!/bin/sh

# Parse (command line) arguments.

. dict

if [ -z ${__parseargs_included_20210604__} ];
then
  __parseargs_included_20210604__=yes

  parseargs_new_argument_parser() {
    local initial_aguments="$(dict_declare_simple)"
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

  parseargs_is_argument_parser() {
    if [ $# -ge 1 ] && \
    [ "$(dict_get_simple "${1}" "__PARSEARG_TYPE__")X" = "argument_parserX" ]; then
      true; return
    else
      false; return
    fi    
  }
fi

#!/bin/bash
# Copyright 2018, Jobcase, Inc. All Rights Reserved.
#
# The software, data, and information (the "Licensed Programs") contained herein are
# proprietary to, and comprise valuable trade secrets of, Jobcase, Inc., which
# intends to keep these Licensed Programs confidential and to preserve them as trade
# secrets. These Licensed Programs are given in confidence by Jobcase, Inc., and
# only pursuant to a written license agreement, and may be used, copied, transmitted,
# and stored only in accordance with the terms of such license.

#
# The script includes logic for searching/creating and updating confluence pages.
#

current_dir=$(pwd)

cd "$(dirname "$(realpath "$0")")" || exit $?

source ../modules/util.sh
source ../modules/jira.sh

function usage() {

  echo "Usage: $0 OPTIONS"

  echo "OPTIONS:"

  echo "--help      | -h    Display this message"
  echo "--verbose   | -v    Verbose output"
  echo "--debug     | -d      Debug/Trace output"

  exit 1
}

#
# Parse command line arguments.
#
function parse() {
  # Option strings
  local SHORT=hvds:
  local LONG=help,verbose,debug,user:,token:,key:,attachment:

  # read the options
  local OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

  if [ $? != 0 ] ; then log_error "Failed to parse options...exiting."; exit 1 ; fi

  eval set -- "$OPTS"

  # set initial values
  VERBOSE=false
  DEBUG=false
  USER=false
  USER_NAME=""
  TOKEN=false
  AUTH_TOKEN=""
  CONTENT_KEY=""
  ATTACHMENT=false
  FILE_NAME=""

  # extract options and their arguments into variables.
  while true ; do
    case "$1" in
      -h | --help )
        usage;;
      -v | --verbose )
        VERBOSE=true
        shift
        ;;
      -d | --debug )
        DEBUG=true
        shift
        ;;
      --user )
        USER=true; USER_NAME="$2"
        shift 2
        ;;
      --token )
        TOKEN=true; AUTH_TOKEN="$2"
        shift 2
        ;;
      --key )
        CONTENT_KEY="$2"
        shift 2
        ;;
      --attachment )
        ATTACHMENT=true; FILE_NAME="$2"
        shift 2
        ;;
      -- )
        shift
        break
        ;;
      *)
        log_error "Incorrect parameter: ${1}"; usage;;
    esac
  done
}

function search() {
	jira_search_ticket ../modules/jira-search-ticket-template.json "${SEARCH_STRING}"

	exit ${exitCode}
}

function create() {
	jira_create_ticket ../modules/jira-create-ticket-template.json "${PROJECT_VALUE}" "${SUMMARY_VALUE}" "${DESCRIPTION_VALUE}"

	exit ${exitCode}
}

unset LOG_FILE
export LOG_FILE=${current_dir}/jira-dev-ops.log

parse "$@"

# verbose mode
if [[ "${VERBOSE}" = true ]]; then
  log_info "enable verbose mode"
  set -o verbose
fi

# debug/trace mode
if [[ "${DEBUG}" = true ]]; then
  log_info "enable debug/trace mode"
  set -o xtrace
fi

jira_authentication "${USER_NAME}" "${AUTH_TOKEN}"

if [ ${exitCode} -ne 0 ]; then
	log_error "REST authentication has failed [${exitCode}]."
  	exit ${exitCode}
fi

if [[ "${ATTACHMENT}" = true ]]; then
	confluence_upload_attachment "${CONTENT_KEY}" "${FILE_NAME}"

	exit ${exitCode}
fi

exit 0

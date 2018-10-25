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
  local LONG=help,verbose,debug,user:,token:,path:

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
  BENCHMARK_RESULT_PATH=""

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
      --path )
        BENCHMARK_RESULT_PATH="$2"
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

unset LOG_FILE
export LOG_FILE=${current_dir}/jira-dev-ops.log

export PARENT_CONFLUENCE_PAGE_ID=445219032
export SPACE_KEY='~95425488'

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

PAGE_TITLE=$(basename ${BENCHMARK_RESULT_PATH})

jira_authentication "${USER_NAME}" "${AUTH_TOKEN}"

confluence_create_page ../modules/create-child-page-template.json "${PAGE_TITLE}" \
	 "${PARENT_CONFLUENCE_PAGE_ID}" "${SPACE_KEY}" ""
exitCode=$?

if [ ${exitCode} -ne 0 ]; then
  log_error "create confluence page failed with exit code ${exitCode}"

  exit ${exitCode}
fi

if [ ${#return_result[@]} -eq 1 ]; then
	NEW_PAGE_ID=$(echo "${return_result[0]}" | jq -r '.id')

	log_info "${NEW_PAGE_ID}"
else
	log_error "invalid create page result [${return_result[0]}] for request"
	exit 1
fi

# upload images
images=$(ls ${BENCHMARK_RESULT_PATH}/*png)

for image_name in ${images}
do
	echo $image_name

	confluence_upload_attachment "${NEW_PAGE_ID}" "${image_name}"
	exitCode=$?

	if [ ${exitCode} -ne 0 ]; then
	  log_error "upload image ${image_name} failed with exit code ${exitCode}"

	  exit ${exitCode}
	fi
done

# extract html body content
# remove body tag
# fix br tag
tag=body
HTLM_CONTENT=$(sed -n "/<$tag>/,/<\/$tag>/p" ${BENCHMARK_RESULT_PATH}/Results.html)
HTLM_CONTENT=$(echo "${HTLM_CONTENT}" | sed -e "/<$tag>/d")
HTLM_CONTENT=$(echo "${HTLM_CONTENT}" | sed -e "/<\/$tag>/d")
HTLM_CONTENT=$(echo "${HTLM_CONTENT}" | sed -e "s/<br>/<br\/>/g")

IMAGE_BASE_URL="https://percipio.jira.com/wiki/download/thumbnails/${NEW_PAGE_ID}"

for image_name in ${images}
do
	image_name=$(basename "${image_name}")

	absolute_url="${IMAGE_BASE_URL}/${image_name}"

	HTLM_CONTENT=${HTLM_CONTENT/${image_name}/${absolute_url}}
done

log_info "updating page with ${HTLM_CONTENT}"

confluence_update_page ../modules/update-page-template.json "${PAGE_TITLE}" \
	 "${NEW_PAGE_ID}" "${SPACE_KEY}" "${HTLM_CONTENT}"

exit 0

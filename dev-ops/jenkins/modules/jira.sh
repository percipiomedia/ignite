#!/bin/bash
# Copyright 2018, Jobcase, Inc. All Rights Reserved.
#
# The software, data, and information (the "Licensed Programs") contained herein are
# proprietary to, and comprise valuable trade secrets of, Jobcase, Inc., which
# intends to keep these Licensed Programs confidential and to preserve them as trade
# secrets. These Licensed Programs are given in confidence by Jobcase, Inc., and
# only pursuant to a written license agreement, and may be used, copied, transmitted,
# and stored only in accordance with the terms of such license.


# Common shell functions for Jira/Confluence


JIRA_DOMAIN="https://percipio.jira.com"

#
# It authenticates against Jira https://percipio.jira.com.
#
# argument:
#  user name (required)
#  password or token (required).
#
# return: It returns the authentication result in ${AUTH_HEADER}
#
function jira_authentication() {
	local user="$1"
  	local token="$2"

  	AUTH_HEADER=$(curl -v ${JIRA_DOMAIN} --user ${user}:${token} 2>&1 | \
                grep Authorization | cut -d '>' -f 2 | xargs)
  	exitCode=$?
}

#
# It executes a search request.
#
# argument:
#  template json file (required).
#  jql string (required).
#  maximum result number (optional). Default is 15.
#
# return: It returns result in the array variable ${return_result}.
#
function jira_search_ticket() {
	local template="$1"
	local search_string="$2"
	local max_result=$3

	if [ -z ${max_result} ]; then
		max_result=15
	fi

	unset return_result

    search_data=$(cat ${template} | \
             jq --arg SEARCH_STRING "${search_string}" \
             --arg MAX_RESULT "${max_result}" \
             '.jql=$SEARCH_STRING | .maxResults=$MAX_RESULT')

    echo "${search_data}" > search_data.json

	result=$(curl \
		-s \
   		-X POST \
		-w 'HTTPSTATUS:%{response_code}' \
   		-H "${AUTH_HEADER}" \
   		-H "Content-Type: application/json" \
   		--data @search_data.json \
   		${JIRA_DOMAIN}/rest/api/2/search)
  	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "REST call [${JIRA_DOMAIN}/rest/api/2/search] has failed [${exitCode}]."
      	return 1
    fi

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "search result ${http_body}"
	log_info "http status result ${http_status}"

	return_result+=("${http_body}")

  	JQ_QUERY='.issues[]|"\(.key)\t\(.id)\t\(.fields.status.name)\t\t\(.fields.summary)"'

	result=$(echo "${http_body}" | jq -r ${JQ_QUERY})
	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
    	log_error "Parsing the result of [${JIRA_DOMAIN}/rest/api/2/search] with jq query [${JQ_QUERY}] has failed."
      	return 1
    fi

    echo -e "${result}"

	return 0
}

#
# It executes a create ticket request.
#
# argument:
#  template json file (required)
#  project name string (required).
#  summary string (required).
#  description string (required).
#
# return: It returns result in the array variable ${return_result}.
#
function jira_create_ticket() {
	local template="$1"
	local project_name="$2"
	local summary="$3"
	local description="$4"

	unset return_result

    request_data=$(cat ${template} | \
  		jq --arg PROJECT_NAME "${project_name}" \
     		--arg TICKET_SUMMARY "${summary}" \
     		--arg TICKET_DESC "${description}" \
     		'.fields.project.id=$PROJECT_NAME | .fields.summary=$TICKET_SUMMARY | .fields.description=$TICKET_DESC')

    echo "${request_data}" > request_data.json

	result=$(curl \
		-s \
   		-X POST \
		-w 'HTTPSTATUS:%{response_code}' \
   		--data @request_data.json \
   		-H "${AUTH_HEADER}" \
   		-H "Content-Type: application/json" \
   		${JIRA_DOMAIN}/rest/api/2/issue)
  	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "REST call [${JIRA_DOMAIN}/rest/api/2/issue] has failed [${exitCode}]."
      	return 1
    fi

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "create result ${http_body}"
	log_info "http status result ${http_status}"

	return_result+=("${http_body}")

	# The request has been fulfilled and has resulted in one new resources being created.
	if [ ${http_status} -ne 201 ]; then
		${exitCode}=${http_status}
		return 1
	fi

  	JQ_QUERY='"\(.key)\t\(.id)\t\(.self)"'

	result=$(echo "${http_body}" | jq -r ${JQ_QUERY})

    echo -e "${result}"

	return 0
}

#
# It adds an comment to an existing ticket.
#
# argument:
#  template json file (required)
#  ticket key (required).
#  comment string (required).
#
# return: It returns result in the array variable ${return_result}.
#
function jira_add_comment_ticket() {
	local template="$1"
	local key="$2"
	local comment="$3"

	unset return_result

    request_data=$(cat ${template} | \
  		jq --arg COMMENT "${comment}" \
     		'.update.comment[0].add.body=$COMMENT')

    echo "${request_data}" > request_data.json

	result=$(curl \
		-s \
   		-X PUT \
		-w 'HTTPSTATUS:%{response_code}' \
   		--data @request_data.json \
   		-H "${AUTH_HEADER}" \
   		-H "Content-Type: application/json" \
   		${JIRA_DOMAIN}/rest/api/2/issue/${key})
  	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "REST call [${JIRA_DOMAIN}/rest/api/2/issue/${key}] has failed [${exitCode}]."
      	return 1
    fi

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "add comment result ${http_body}"
	log_info "http status result ${http_status}"

	if [ ${http_status} -ne 204 ]; then
		${exitCode}=${http_status}
		return 1
	fi

	return_result+=("${http_body}")
}

#
# It adds an attachment to an existing ticket.
#
# argument:
#  ticket key (required).
#  attachment file (required).
#
# return: It returns result in the array variable ${return_result}.
#
function jira_add_attachment_ticket() {
	local key="$1"
	local attachment="$2"

	unset return_result

	result=$(curl \
		-s \
		-X POST \
		-w 'HTTPSTATUS:%{response_code}' \
		-H "${AUTH_HEADER}" \
		-H "X-Atlassian-Token: nocheck" \
		-F "file=@${attachment}" \
		${JIRA_DOMAIN}/rest/api/2/issue/${key}/attachments)
  	exitCode=$?

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "attachment result ${http_body}"
	log_info "http status result ${http_status}"

	if [ ${http_status} -ne 200 ]; then
		${exitCode}=${http_status}
		return 1
	fi

	return_result+=("${http_body}")
}

#
# It updates status of an existing ticket.
#
# argument:
#  template json file (required)
#  ticket key (required).
#  resolution string (required).
#  status id number (required).
#		10000 in-progress
#		2	  close
#		6	  closed
#		3	  reopen
#       4     reopened
#
# return: It returns result in the array variable ${return_result}.
#
function jira_update_status_ticket() {
	local template="$1"
	local key="$2"
	local resolution="$3"
	local status="$4"
	local status_id="10000"

	unset return_result

	case "${status}" in
		in-progress )
			status_id="10000"
        	;;
		close )
			status_id="2"
        	;;
		closed )
			status_id="6"
        	;;
		reopen )
			status_id="3"
			;;
		reopened )
			status_id="4"
			;;
	esac

    request_data=$(cat ${template} | \
  		jq --arg RESOLUTION "${resolution}" \
  		  --arg STATUSID "${status_id}" \
     	  '.fields.resolution.name=$RESOLUTION | .transition.id=$STATUSID')

	if [ ${status_id} -eq 3 ]; then
		# remove resolution from request
		echo "${request_data}" | jq 'del(.fields)' > request_data.json
	else
    	echo "${request_data}" > request_data.json
	fi

	result=$(curl \
		-s \
   		-X POST \
		-w 'HTTPSTATUS:%{response_code}' \
   		--data @request_data.json \
   		-H "${AUTH_HEADER}" \
   		-H "Content-Type: application/json" \
   		${JIRA_DOMAIN}/rest/api/2/issue/${key}/transitions)
  	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "REST call [${JIRA_DOMAIN}/rest/api/2/issue/${key}/transitions] has failed [${exitCode}]."
      	return 1
    fi

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "update status result ${http_body}"
	log_info "http status result ${http_status}"

	return_result+=("${http_body}")
}

function jira_delete_ticket() {
	local key="$1"

	result=$(curl \
		-s \
		-w 'HTTPSTATUS:%{response_code}' \
   		-X DELETE \
   		-H "${AUTH_HEADER}" \
   		-H "Content-Type: application/json" \
   		${JIRA_DOMAIN}/rest/api/2/issue/${key})
  	exitCode=$?

	log_info "delete ticket result ${result}"

	return_result+=("${result}")
}

function jira_create_meta_ticket() {
	result=$(curl --request GET \
		-w 'HTTPSTATUS:%{response_code}' \
	    --silent \
  		--url "${JIRA_DOMAIN}/rest/api/2/issue/createmeta" \
  		--header "${AUTH_HEADER}" \
  		--header "Accept: application/json")

  	echo "${result}" > meta-result.json
}

#
# It adds an attachment to an existing confluence page.
#
# argument:
#  content id key (required).
#  attachment file (required).
#
# return: It returns result in the array variable ${return_result}.
#
function confluence_upload_attachment() {
	local key="$1"
	local attachment="$2"

	unset return_result

	result=$(curl \
		-s \
		-X POST \
		-w 'HTTPSTATUS:%{response_code}' \
		-H "${AUTH_HEADER}" \
		-H "X-Atlassian-Token: nocheck" \
		-F "file=@${attachment}" \
		${JIRA_DOMAIN}/confluence/rest/api/content/${key}/child/attachment)
  	exitCode=$?

	# extract the body
	http_body=$(echo $result | sed -e 's/HTTPSTATUS\:.*//g')

	# extract the status
	http_status=$(echo $result | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

	log_info "attachment result ${http_body}"
	log_info "http status result ${http_status}"

	if [ ${http_status} -ne 200 ]; then
		${exitCode}=${http_status}
		return 1
	fi

	return_result+=("${http_body}")
}

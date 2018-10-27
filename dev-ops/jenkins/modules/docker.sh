#!/bin/bash
# Copyright 2018, Jobcase, Inc. All Rights Reserved.
#
# The software, data, and information (the "Licensed Programs") contained herein are
# proprietary to, and comprise valuable trade secrets of, Jobcase, Inc., which
# intends to keep these Licensed Programs confidential and to preserve them as trade
# secrets. These Licensed Programs are given in confidence by Jobcase, Inc., and
# only pursuant to a written license agreement, and may be used, copied, transmitted,
# and stored only in accordance with the terms of such license.


# Common shell functions for docker CLI

#
# It determines the ip-address of a running docker container.
#
# argument:
#  container name/id string (required).
#
# return: It returns result in the array variable ${return_result}.
#
function docker_get_container_ip() {
	local container_id="$1"

	unset return_result

	result=$(docker inspect -f "{{ .NetworkSettings.IPAddress }}" ${container_id} 2>&1)
	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "get ip-address failed [${exitCode}] [${result}]."
      	return 1
    fi

	return_result+=("${result}")

	return 0
}

#
# It executes command(s) against docker container.
#
# argument:
#  container name/id string (required).
#  command(s) string/string array (required).
#
# return: It returns result in the array variable ${return_result}.
#
function docker_exec() {
	local container_id="$1"
	local commands="$2"

	unset return_result

	result=$(docker exec ${container_id} ${commands} 2>&1)
	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "exec failed [${exitCode}] [${result}]."
      	return 1
    fi

	return_result+=("${result}")

	return 0
}

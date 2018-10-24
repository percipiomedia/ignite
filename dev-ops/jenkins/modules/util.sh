#!/bin/bash
# Copyright 2018, Jobcase, Inc. All Rights Reserved.
#
# The software, data, and information (the "Licensed Programs") contained herein are
# proprietary to, and comprise valuable trade secrets of, Jobcase, Inc., which
# intends to keep these Licensed Programs confidential and to preserve them as trade
# secrets. These Licensed Programs are given in confidence by Jobcase, Inc., and
# only pursuant to a written license agreement, and may be used, copied, transmitted,
# and stored only in accordance with the terms of such license.


# Common shell functions for Jobcase DevOps

LOG_DATE='date +%Y/%m/%d:%H:%M:%S'

if [ -z ${LOG_FILE} ]; then
  LOG_FILE=ecs-dev-ops.log
fi

declare -a return_result=()

#
# Append log message as INFO to log file.
# The log message gets written to log file.
#
function log_info {
  # Check log file exists.
  # If the file does not exist it will be created.
  test -f ${LOG_FILE} || touch ${LOG_FILE}

  echo `$LOG_DATE`" INFO [$(basename ${BASH_SOURCE[1]})] ${1}" >> ${LOG_FILE}
}

#
# Append log message as ERROR to log fie.
#
function log_error {
  test -f ${LOG_FILE} || touch ${LOG_FILE}

  echo `$LOG_DATE`" ERROR [$(basename ${BASH_SOURCE[1]})] ${1}" >> ${LOG_FILE}
}

#
# It returns the cluster name(s) in the ECS environment.
#
# return: The names are returned in the array variable ${return_result}.
#
function list_clusters() {
  unset return_result

  clusters=$(aws ecs list-clusters --no-paginate | jq -r '.clusterArns[]')
  exitCode=$?

  for cluster in ${clusters[*]}
  do
    cluster_name=$(echo ${cluster} | cut -d '/' -f 2)

    log_info "${cluster_name}"

    return_result+=("${cluster_name}")
  done
}

#
# It returns the ECS host ip-addresses in a ECS cluster.
#
# argument: The name of the ECS cluster (required)
# return: The ip-addresses are returned in the array variable ${return_result}.
#
function get_ecs_host_ips() {
	local cluster_name="$1"

	unset return_result

	# list all ECS instances in the cluster
	container_instances=$(aws ecs list-container-instances --cluster ${cluster_name} | jq -r '.containerInstanceArns[]')
	exitCode=$?

	for ci in ${container_instances[*]}
	do
	  ci_id=$(echo ${ci} | cut -d '/' -f 2)

	  result=$(aws ecs describe-container-instances --cluster ${cluster_name} --container-instances ${ci_id})

	  inst_id=$(echo ${result} | jq -r '.containerInstances[0].ec2InstanceId')

	  ecs_host_ipaddress=$(aws ec2 describe-instances --instance-ids ${inst_id} \
	         | jq -r '.Reservations[].Instances[].NetworkInterfaces[0].PrivateIpAddress')

      return_result+=("${ecs_host_ipaddress}")
	done
}

#
# It returns the Snapshot Container ip-addresses in a ECS cluster.
#
# argument: The name of the ECS cluster (required)
# return: The ip-addresses are returned in the array variable ${return_result}.
#
function get_snapshot_container_ipaddress() {
	local ecs_cluster_name="$1"
	local snapshot_container_name=IgniteSnapshotImage

	unset return_result

	tasks=$(aws ecs list-tasks --cluster ${ecs_cluster_name} | jq -r '.taskArns[]')
	exitCode=$?

	for task in ${tasks[*]}
	do
	  task_id=$(echo ${task} | cut -d '/' -f 2)

	  log_info "${task_id}"

	  first_container=$(aws ecs describe-tasks --cluster ${ecs_cluster_name} --task ${task_id} | jq -r '.tasks[].containers[0]')

	  log_info "${first_container}"

	  container_name=$(echo ${first_container} | jq -r '.name')

	  log_info "${container_name}"

	  if [[ "${snapshot_container_name}" = ${container_name} ]]; then
	    private_ip=$(echo ${first_container} | jq -r '.networkInterfaces[0].privateIpv4Address')

	    log_info "${snapshot_container_name} ip-address ${private_ip}"

	    snapshot_container_ipaddress=${private_ip}

        return_result+=("${private_ip}")
	  fi
	done
}

#
# It returns the host ips of a AWS auto scaling group.
#
# argument:
#  The auto scaling group name (required)
#
# return: The call result is returned in the array variable ${return_result}.
#
# Example: get_auto_scaling_group_host_ips ECSIgnite02Staging
#
function get_auto_scaling_group_host_ips() {
	local auto_group="$1"

	unset return_result

	return_result=$(aws ec2 describe-instances  --filters "Name=tag:aws:autoscaling:groupName,Values=${auto_group}" "Name=instance-state-name,Values=running" --no-paginate | jq -r '.Reservations[].Instances[] | .PrivateIpAddress')
}

#
# It executes ssh call with /bin/bash -c <command string>.
#
# argument:
#  The ip address of the host (required)
#  Command string (required).
#
# return: The ssh call result is returned in the array variable ${return_result}.
#
function execute_ssh() {
	local ip_address="$1"
	local cmd="$2"

	unset return_result

	result=$(ssh -o UserKnownHostsFile=/dev/null -q -o StrictHostKeyChecking=no -tt ec2-user@${ip_address} \
	         /bin/bash -c "${cmd}" 2>&1)
  	exitCode=$?

	return_result+=("${result}")
}

function anywait_w_status2() {
    while true
    do
        alive_pids=()
        for pid in "$@"
        do
            kill -0 "$pid" 2>/dev/null \
                && alive_pids+=("$pid")
        done

        if [ ${#alive_pids[@]} -eq 0 ]
        then
            break
        fi

        log_info "Process(es) still running... ${alive_pids[@]}"
        sleep 1
    done
    log_info "All processes terminated"
}

#
# It decodes ec2 authorization failure message.
# It looks for the text 'Encoded authorization failure message:' in the ec2 command output.
#
# argument:
#  output of the ec2 command (required)
#
# return: The result is returned in the array variable ${return_result}.
#
function ec2_decode_authorization_message() {
	local output="$1"

	unset return_result

	encoded=$(awk -F'Encoded authorization failure message: ' '{print $2}' <<< ${output})

	if [ -n "${encoded}" ]; then
		log_info "decoding authorization message ${encoded}"

		result=$(aws sts decode-authorization-message --encoded-message "${encoded}")
		exitCode=$?

		log_info "decoding authorization message result [${result}] [${exitCode}]"

		return_result+=("${result}")
	fi
}
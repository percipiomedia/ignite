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
# The script includes logic for running Apache Ignite Benchmarks.
#

current_dir=$(pwd)

cd "$(dirname "$(realpath "$0")")" || exit $?

source ../modules/util.sh
source ../modules/jira.sh
source ../modules/docker.sh

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
  local LONG=help,verbose,debug,num-nodes:,jvm-heap-size:,jvm-meta-size:,stop:,runall:,runmlstore:,hprof:,jfr:,threadcount:

  # read the options
  local OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

  if [ $? != 0 ] ; then log_error "Failed to parse options...exiting."; exit 1 ; fi

  eval set -- "$OPTS"

  # set initial values
  VERBOSE=false
  DEBUG=false
  NUM_NODES=2
  JVM_HEAP_SIZE='2g'
  JVM_METASPACE_SIZE='2g'
  STOP_CONTAINERS=true
  RUN_ALL=false
  RUN_MLSTORE=false
  HPROF=false
  JFR=false
  THREADCOUNT=64

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
      --num-nodes )
        NUM_NODES="$2"
        shift 2
        ;;
      --jvm-heap-size )
        JVM_HEAP_SIZE="$2"
        shift 2
        ;;
      --jvm-meta-size )
        JVM_METASPACE_SIZE="$2"
        shift 2
        ;;
      --stop )
        STOP_CONTAINERS="$2"
        shift 2
        ;;
      --runall )
        RUN_ALL="$2"
        shift 2
        ;;
      --runmlstore )
        RUN_MLSTORE="$2"
        shift 2
        ;;
      --hprof )
        HPROF="$2"
        shift 2
        ;;
      --jfr )
        JFR="$2"
        shift 2
        ;;
      --threadcount )
        THREADCOUNT="$2"
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

export JVM_HPROF="-agentlib:hprof=heap=all,cpu=samples,monitor=n,format=b,file=HPROF_FILE"

export JVM_FLIGHT_RECORDER="-XX:+UnlockCommercialFeatures \
-XX:+FlightRecorder \
-XX:FlightRecorderOptions=defaultrecording=true,disk=true,repository=./tmp,dumponexit=true,dumponexitpath=JFR_FILE"

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

if [[ "${HPROF}" = true ]]; then
  log_info "enable hprof profiling"
  export JVM_PROFILING="${JVM_HPROF}"
elif [[ "${JFR}" = true ]]; then
  log_info "enable JFR profiling"
  export JVM_PROFILING="${JVM_FLIGHT_RECORDER}"
fi

declare -a node_names=()

# index array with node name as indexes
declare -a node_ip_addresses=()

declare node_discovery_xml_list=""
declare server_hosts_prop=""

idx=0

# generate node names
while [ ${idx} -lt ${NUM_NODES} ]
do
	node_name="ignite-jobcase-data${idx}"

	node_names+=("${node_name}")

	let idx=idx+1
done

# write docker hostname and ip to file under persistent store path
result=$(echo "DOCKER_HOST_NAME=$(hostname)" | sudo tee /home/ec2-user/mgay/ignite_nodes/db/host.info)
result=$(/sbin/ip route get 1 | awk '{print "DOCKER_HOST_IP="$NF;exit}' | sudo tee -a /home/ec2-user/mgay/ignite_nodes/db/host.info)

for node_name in ${node_names[*]}
do
	log_info "launch node ${node_name}"

	result=$(docker run \
        -d=true \
        -v /home/ec2-user/mgay/ignite_nodes/logs/${node_name}:/opt/jobcase/logs \
        -v /home/ec2-user/mgay/ignite_nodes/db:/opt/jobcase/data \
        -v /home/ec2-user/mgay/ignite_nodes/discovery:/opt/jobcase/discovery \
        -v /home/ec2-user/workspace/ValidateIgniteSnapshot/dev-ops:/opt/jobcase/dev-ops \
        -v /var/run/jobcase-snapshot.sock:/var/run/jobcase-snapshot.sock \
        -e IGNITE_CONSISTENT_ID=${node_name} \
        -e "CONFIG_URI=file:///opt/jobcase/config/multicast.discovery.node.config.xml" \
        -e JVM_HEAP_SIZE=${JVM_HEAP_SIZE} \
        -e JVM_METASPACE_SIZE=${JVM_METASPACE_SIZE} \
        -e IGNITE_STRIPED_POOL_SIZE=${IGNITE_STRIPED_POOL_SIZE} \
        --name=${node_name} apacheignite/jobcase:2.5.0 \
        --debug --launch ls 2>&1)
	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "docker run failed [${exitCode}] [${result}]."
      	exit ${exitCode}
    fi

    # add and start ssh server (sshd)
    # and add dstat for benchmark data
	docker exec ${node_name} apt-get update
	docker exec ${node_name} apt-get install ssh openssh-server dstat -y
	docker exec ${node_name} mkdir -p /run/sshd
	docker exec ${node_name} mkdir -p /root/.ssh
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/ssh/id_rsa.pub ${node_name}:/root/.ssh/authorized_keys
	docker exec ${node_name} chown root /root/.ssh/authorized_keys
	docker exec ${node_name} chgrp root /root/.ssh/authorized_keys
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/ssh/sshd_config ${node_name}:/etc/ssh

	result=$(docker exec --detach ${node_name} /usr/sbin/sshd &)
	exitCode=$?

    if [ ${exitCode} -ne 0 ]; then
		log_error "launch sshd failed [${exitCode}] [${result}]."
      	exit ${exitCode}
    fi

    # get ip-address
    docker_get_container_ip ${node_name}

    ip_address="${return_result[0]}"

    log_info "container [${node_name}] ip-address [${ip_address}]"

    node_ip_addresses[${node_name}]="${ip_address}"

    node_discovery_xml_list="${node_discovery_xml_list}<value>${ip_address}:47500<\/value>"

    if [ "${server_hosts_prop}" != "" ]; then
    	server_hosts_prop="${server_hosts_prop},"
	fi

    server_hosts_prop="${server_hosts_prop}${ip_address}"
done

# add remote node ip information to benchmark files
sed -e "s/IPLIST/${node_discovery_xml_list}/g" \
	${WORKSPACE}/dev-ops/jenkins/benchmarks/config/ignite-remote-config-template.xml > ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/ignite-remote-config.xml

sed -e "s/IPLIST/${node_discovery_xml_list}/g" \
	${WORKSPACE}/dev-ops/jenkins/benchmarks/config/mlstore-config-template.xml > ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/mlstore-config.xml

if [ ${RUN_MLSTORE} = true ]; then
	sed -e "s/IPLIST/${server_hosts_prop}/g" \
	    -e "s/THREADCOUNT/${THREADCOUNT}/g" \
		${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-mlstore-template.properties > ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-mlstore.properties
elif [ ${RUN_ALL} = true ]; then
	sed -e "s/IPLIST/${server_hosts_prop}/g" \
		${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-all-template.properties > ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-all.properties
else
	sed -e "s/IPLIST/${server_hosts_prop}/g" \
		${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-sample-template.properties > ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-sample.properties
fi

##########################################################################################
# start ignite snapshot service node
snap_node_name='ignite-jobcase-snapshot'

docker run \
        -d=true \
        -v /home/ec2-user/mgay/ignite_nodes/logs/${snap_node_name}:/opt/jobcase/logs \
        -v /home/ec2-user/mgay/ignite_nodes/db:/opt/jobcase/data \
        -v /home/ec2-user/mgay/ignite_nodes/discovery:/opt/jobcase/discovery \
        -v /var/run/jobcase-snapshot.sock:/var/run/jobcase-snapshot.sock \
        -e IGNITE_CONSISTENT_ID=${snap_node_name} \
        -e "CONFIG_URI=file:///opt/jobcase/config/multicast.discovery.snapshot.service.client.node.config.xml" \
        -e JVM_HEAP_SIZE=${JVM_HEAP_SIZE} \
        -e JVM_METASPACE_SIZE=${JVM_METASPACE_SIZE} \
        -e IGNITE_STRIPED_POOL_SIZE=${IGNITE_STRIPED_POOL_SIZE} \
        -e "JVM_PROFILING=${JVM_PROFILING}" \
        --name=${snap_node_name} apacheignite/jobcase-snapshot:2.5.0 \
        --debug --launch ls

# get IGNITE_HOME env
ignite_home=$(docker exec ${snap_node_name} printenv IGNITE_HOME)

# benchmark-wait-driver-up.sh requires bc app
# and add dstat for benchmark data
docker exec ${snap_node_name} apt-get update
docker exec ${snap_node_name} apt-get install bc dstat -y

if [ ${RUN_MLSTORE} = true ]; then
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/mlstore-config.xml ${snap_node_name}:${ignite_home}/benchmarks/config/
fi

docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/ignite-remote-config.xml ${snap_node_name}:${ignite_home}/benchmarks/config/

if [ ${RUN_MLSTORE} = true ]; then
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-mlstore.properties ${snap_node_name}:${ignite_home}/benchmarks/config/
elif [ ${RUN_ALL} = true ]; then
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-all.properties ${snap_node_name}:${ignite_home}/benchmarks/config/
else
	docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/config/benchmark-remote-sample.properties ${snap_node_name}:${ignite_home}/benchmarks/config/
fi

# updated version of benchmark script files
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/script/benchmark-drivers-start.sh ${snap_node_name}:${ignite_home}/benchmarks/bin/
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/script/benchmark-servers-start.sh ${snap_node_name}:${ignite_home}/benchmarks/bin/
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/script/benchmark-bootstrap.sh ${snap_node_name}:${ignite_home}/benchmarks/bin/
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/script/benchmark-run-all.sh ${snap_node_name}:${ignite_home}/benchmarks/bin/
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/script/benchmark-servers-stop.sh ${snap_node_name}:${ignite_home}/benchmarks/bin/

docker exec ${snap_node_name} mkdir -p /root/.ssh
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/ssh/id_rsa ${snap_node_name}:/root/.ssh/
docker cp ${WORKSPACE}/dev-ops/jenkins/benchmarks/ssh/id_rsa.pub ${snap_node_name}:/root/.ssh/

# execute benchmark
if [ ${RUN_MLSTORE} = true ]; then
	docker exec ${snap_node_name} /bin/bash -c "cd ${ignite_home}/benchmarks/ && ./bin/benchmark-run-all.sh config/benchmark-remote-mlstore.properties"
elif [ ${RUN_ALL} = true ]; then
	docker exec ${snap_node_name} /bin/bash -c "cd ${ignite_home}/benchmarks/ && ./bin/benchmark-run-all.sh config/benchmark-remote-all.properties"
else
	docker exec ${snap_node_name} /bin/bash -c "cd ${ignite_home}/benchmarks/ && ./bin/benchmark-run-all.sh config/benchmark-remote-sample.properties"
fi

# tar outcome
docker exec ${snap_node_name} /bin/bash -c "cd ${ignite_home}/benchmarks/ && tar cvfz benchmark.tar.gz output"

docker exec ${snap_node_name} cat ${ignite_home}/benchmarks/benchmark.tar.gz > ${WORKSPACE}/benchmark${BUILD_NUMBER}.tar.gz

if [ ${STOP_CONTAINERS} = true ]; then
	# stop containers
	docker stop ${snap_node_name} ${node_names[*]}

	# delete stopped container(s)
	docker container prune --force
fi

exit 0

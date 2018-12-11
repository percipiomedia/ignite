#!/bin/bash -x

#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.

#
# Script that stops BenchmarkServer on remote machines.
# This script expects the argument to be a path to run properties file which contains
# the list of remote nodes to start server on and the list of configurations.
#

# Define script directory.
SCRIPT_DIR=$(cd $(dirname "$0"); pwd)

CONFIG_INCLUDE=$1

if [ "${CONFIG_INCLUDE}" == "-h" ] || [ "${CONFIG_INCLUDE}" == "--help" ]; then
    echo "Usage: benchmark-servers-stop.sh [PROPERTIES_FILE_PATH]"
    echo "Script that stops BenchmarkServer on remote machines."
    exit 1
fi

if [ "${CONFIG_INCLUDE}" == "" ]; then
    CONFIG_INCLUDE=${SCRIPT_DIR}/../config/benchmark.properties
    echo "<"$(date +"%H:%M:%S")"><yardstick> Using default properties file: 'config/benchmark.properties'."
fi

if [ ! -f $CONFIG_INCLUDE ]; then
    echo "ERROR: Properties file is not found."
    echo "Type \"--help\" for usage."
    exit 1
fi

shift

CONFIG_TMP=`mktemp tmp.XXXXXXXX`

cp $CONFIG_INCLUDE $CONFIG_TMP
chmod +x $CONFIG_TMP

. $CONFIG_TMP
rm $CONFIG_TMP

# Define user to establish remote ssh session.
if [ "${REMOTE_USER}" == "" ]; then
    REMOTE_USER=$(whoami)
fi

if [ "${SERVER_HOSTS}" == "" ]; then
    echo "ERROR: Benchmark hosts (SERVER_HOSTS) is not defined in properties file."
    echo "Type \"--help\" for usage."
    exit 1
fi

if [ "${REMOTE_USER}" == "" ]; then
    echo "ERROR: Remote user (REMOTE_USER) is not defined in properties file."
    echo "Type \"--help\" for usage."
    exit 1
fi

pkill -9 -f "benchmark-server-restarter-start.sh"

if [[ "${RESTART_SERVERS}" != "" ]] && [[ "${RESTART_SERVERS}" != "true" ]]; then
    echo "<"$(date +"%H:%M:%S")"><yardstick> All server restarts are stopped."
fi

DS=""

id=0

IFS=',' read -ra hosts0 <<< "${SERVER_HOSTS}"
for host_name in "${hosts0[@]}";
do

    # Extract description.
    IFS=' ' read -ra cfg0 <<< "${CONFIG}"
    for cfg00 in "${cfg0[@]}";
    do
        if [[ ${found} == 'true' ]]; then
            found=""
            DS=${cfg00}
        fi

        if [[ ${cfg00} == '-ds' ]] || [[ ${cfg00} == '--descriptions' ]]; then
            found="true"
        fi
    done

    if [[ ${host_name} = "127.0.0.1" || ${host_name} = "localhost" ]]
        then
            pkill -9 -f "Dyardstick.server"
        else
            `ssh -o PasswordAuthentication=no ${REMOTE_USER}"@"${host_name} pkill -15 -f "Dyardstick.server"`

            sleep 2s

            result=$(ssh -o PasswordAuthentication=no ${REMOTE_USER}"@"${host_name} pgrep -f "Dyardstick.server" 2>&1)
            exitCode=$?

            # rename benchmark test output folder
            src_output_folder=$(ssh -o PasswordAuthentication=no ${REMOTE_USER}"@"${host_name} find "${OUTPUT_FOLDER#--outputFolder }" -name "*${DS}" 2>&1)
            exitCode=$?

            if [ ${exitCode} -eq 0 ]; then
              echo "src_output_folder [${src_output_folder}]"

              date_time=$(date +"%Y%m%d-%H%M%S")

              dest_output_folder=${OUTPUT_FOLDER#--outputFolder }/${date_time}-server-id${id}-${host_name}-${DS}

              echo "dest_output_folder [${dest_output_folder}]"

              rename_output_folder_res=$(ssh -o PasswordAuthentication=no ${REMOTE_USER}"@"${host_name} mv "${src_output_folder}" "${dest_output_folder}" 2>&1)
              exitCode=$?

              echo "rename output folder result [${rename_output_folder_res}]"

              # move java flight recorder result
              result=$(ssh -o PasswordAuthentication=no ${REMOTE_USER}"@"${host_name} mv "${OUTPUT_FOLDER#--outputFolder }/probe.jfr" "${dest_output_folder}" 2>&1)
              exitCode=$?

              echo "move java flight recorder result [${result}]"
            fi
        fi

    echo "<"$(date +"%H:%M:%S")"><yardstick> Server is stopped on "${host_name}" with id=${id}"

    id=$((1 + $id))

done

#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [ ! -z "$OPTION_LIBS" ]; then
  IFS=, LIBS_LIST=("$OPTION_LIBS")

  for lib in ${LIBS_LIST[@]}; do
    cp -r $IGNITE_HOME/libs/optional/"$lib"/* \
        $IGNITE_HOME/libs/
  done
fi

if [ ! -z "$EXTERNAL_LIBS" ]; then
  IFS=, LIBS_LIST=("$EXTERNAL_LIBS")

  for lib in ${LIBS_LIST[@]}; do
    wget $lib -P $IGNITE_HOME/libs
  done
fi

# Load docker host information
# automatically export all variables in host.info
set -a
source $IGNITE_PERSISTENT_STORE/host.info
set +a

# form a consistent ID from the ECS host's name and the cluster name
if [ -z "$IGNITE_CONSISTENT_ID" ]; then
    if [ ! -z "$IGNITE_CLUSTER_NAME" ]  && [ ! -z "$IGNITE_PERSISTENT_STORE" ]  &&  [ -f "$IGNITE_PERSISTENT_STORE/hostname" ]; then
        export IGNITE_CONSISTENT_ID=${IGNITE_CLUSTER_NAME}-${DOCKER_HOST_NAME}
    fi
fi

# Datadog seems to require that java.rmi.server.hostname be set.  
# There is confusion as to what happens if the datadog container is using a different network mode.
if [ ! -z $IGNITE_JMX_PORT ]; then
    HOST_IP=`hostname -i`
    export JVM_DEBUG_OPTS="-Djava.rmi.server.hostname=${HOST_IP} $JVM_DEBUG_OPTS"
fi

export JVM_OPTS="$JVM_OPTS $JVM_DEBUG_OPTS $JVM_ADDITIONAL_OPTS"

if [ ! -z "${JVM_IGNITE_GC_LOGGING_OPTS}" ] &&  [ ! -z "${JOBCASE_LOGS}" ]; then
    export JVM_OPTS="$JVM_OPTS $JVM_IGNITE_GC_LOGGING_OPTS  -Xloggc:${JOBCASE_LOGS}/jvm-gc.log"
fi

if [ ! -z "${JVM_METASPACE_SIZE}" ]; then
    export JVM_OPTS="$JVM_OPTS -XX:MaxMetaspaceSize=${JVM_METASPACE_SIZE}"
fi

if [ ! -z "${JVM_HEAP_SIZE}" ]; then
    export JVM_OPTS="$JVM_OPTS -Xms${JVM_HEAP_SIZE} -Xmx${JVM_HEAP_SIZE}"
fi

QUIET=""

if [ "$IGNITE_QUIET" = "false" ]; then
  QUIET="-v"
fi

# If IGNITE_AUTO_BASELINE_DELAY is specifed, spawn a separate background task to force activate 
# the cluster if the current node is not part of the baseline after the delay.   The delay
# needs to be shorter than the health check startup time.
if [ ! -z "$IGNITE_CONSISTENT_ID" ]  && [ "$IGNITE_AUTO_BASELINE_DELAY" -ne 0 ]; then
    $IGNITE_HOME/autobaseline.sh $IGNITE_CONSISTENT_ID $IGNITE_AUTO_BASELINE_DELAY &
fi

if [ -z $CONFIG_URI ]; then
  $IGNITE_HOME/bin/ignite.sh $QUIET
else
  $IGNITE_HOME/bin/ignite.sh $QUIET $CONFIG_URI
fi

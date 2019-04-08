#!/bin/bash

id

echo "${WORKSPACE}"

container_ip="172.17.0.2"

# get container id
container_id=$(docker ps --filter "name=ignite-jobcase" --quiet | awk '{print $1}')

if [ -n "${container_id}" ]; then
  docker stop ${container_id}
fi

# delete stopped container(s)
docker container prune --force

# start ignite container
# bridge network
docker run \
        -d=true \
        -v /home/ec2-user/mgay/ignite_nodes_2_7/logs:/opt/jobcase/logs \
        -v /home/ec2-user/mgay/ignite_nodes_2_7/db:/opt/jobcase/data \
        -v /home/ec2-user/mgay/ignite_nodes_2_7/discovery:/opt/jobcase/discovery \
        -e IGNITE_CONSISTENT_ID=`hostname` \
        -e IGNITE_AUTO_BASELINE_DELAY=60 \
        --name=ignite-jobcase apacheignite/jobcase:2.7.0

# get container id
container_id=$(docker ps --filter "name=ignite-jobcase" --quiet | awk '{print $1}')

echo "${container_id}"

# get IGNITE_HOME env
ignite_home=$(docker exec ${container_id} printenv IGNITE_HOME)

# activate grid
sleep 120
# docker exec ${container_id} ${ignite_home}/bin/control.sh --activate

# get IGNITE_REST_PORT env
ignite_rest_port=$(docker exec ${container_id} printenv IGNITE_REST_PORT)

result=$(curl -s "http://${container_ip}:${ignite_rest_port}/ignite?cmd=version")

# "successStatus":0
[[ ${result} = *\"successStatus\":0* ]] && echo Yes || exit 1

result=$(curl -s "http://${container_ip}:${ignite_rest_port}/ignite?cmd=node&ip=${container_ip}")

[[ ${result} = *\"successStatus\":0* ]] && echo Yes || exit 1

key="key"
value="val.test-cache."
cache="test-cache"

# create cache test-cache
result=$(curl -s "http://${container_ip}:${ignite_rest_port}/ignite?cmd=getorcreate&cacheName=${cache}")

[[ ${result} = *\"successStatus\":0* ]] && echo Yes || exit 1

# add 100 entries to test-cache
for i in {1..100}
do
  result=$(curl -s "http://${container_ip}:${ignite_rest_port}/ignite?cmd=add&key=${key}${i}&val=${value}${i}&cacheName=${cache}")

  [[ ${result} = *\"successStatus\":0* ]] && echo Yes || exit 1
done

# stop ignite container
docker stop ${container_id}
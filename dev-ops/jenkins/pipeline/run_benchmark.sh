#!/bin/bash

# params: json and prop
function jsonval {
    temp=`echo $json | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w $prop`
    echo ${temp##*|}
}

id

env

echo "workspace ${WORKSPACE}"
echo "use compute ${USE_COMPUTE}"

find ${WORKSPACE}/dev-ops/jenkins -name "*.sh" -print0 | xargs -0 chmod +x

ls -al ${WORKSPACE}/dev-ops/jenkins/commands/RunBenchmark.sh

if [ -n "${RUN_BENCHMARK_PROP_FILE}" ]; then
  ${WORKSPACE}/dev-ops/jenkins/commands/RunBenchmark.sh --debug \
	--num-nodes ${NUM_NODES} \
	--jvm-heap-size ${JVM_HEAP_SIZE} --jvm-meta-size ${JVM_METASPACE_SIZE} \
    --run ${RUN_BENCHMARK_PROP_FILE} \
    --jfr ${JAVA_FLIGHT_RECORDER} \
    --threadcount ${THREAD_COUNT} \
    --stop ${STOP_CONTAINERS}
else
  ${WORKSPACE}/dev-ops/jenkins/commands/RunBenchmark.sh --debug \
	--num-nodes ${NUM_NODES} \
	--jvm-heap-size ${JVM_HEAP_SIZE} --jvm-meta-size ${JVM_METASPACE_SIZE} \
    --runall ${RUN_ALL} \
    --runmlstore ${RUN_MLSTORE} \
    --jfr ${JAVA_FLIGHT_RECORDER} \
    --threadcount ${THREAD_COUNT} \
    --stop ${STOP_CONTAINERS}
fi

source ${WORKSPACE}/dev-ops/jenkins/modules/util.sh

# create csv file from environment variables
csv_file="csv_env_${BUILD_NUMBER}.csv"

env_result=$(env | grep -v TERMCAP)

for line in ${env_result}
do
  echo "${line/=/,}" >> "${csv_file}"
done

# convert env csv to html table
convert_csv_html "${csv_file}"

html_env_table="${return_result[*]}"

echo "${html_env_table}"

# create build page

PAGE_TITLE="IgniteBenchmarkResult-${BUILD_NUMBER}"

result=$(${WORKSPACE}/dev-ops/jenkins/commands/Confluence.sh --debug \
  --user "${JIRA_USER_NAME}" --token "${JIRA_AUTH_TOKEN}" \
  --create "${PAGE_TITLE}" \
  --parent "${PARENT_CONFLUENCE_PAGE_ID}" \
  --space "${CONFLUENCE_SPACE_KEY}" --content "${html_env_table}")

NEW_BUILD_PAGE_ID=$(echo "${result}" | jq -r '.id')

# upload benchmark result to confluence

${WORKSPACE}/dev-ops/jenkins/commands/Confluence.sh --debug \
  --user "${JIRA_USER_NAME}" --token "${JIRA_AUTH_TOKEN}" \
  --key "${NEW_BUILD_PAGE_ID}" --attachment "${WORKSPACE}/benchmark${BUILD_NUMBER}.tar.gz"

tar xvfz ${WORKSPACE}/benchmark${BUILD_NUMBER}.tar.gz

for results_file in $(ls ${WORKSPACE}/output/results*/*RELEASE*/Results.html)
do
	results_path=$(dirname ${results_file})

	${WORKSPACE}/dev-ops/jenkins/commands/UploadBenchmarkResult.sh --debug \
  		--user "${JIRA_USER_NAME}" --token "${JIRA_AUTH_TOKEN}" \
  		--spacekey "${CONFLUENCE_SPACE_KEY}" --parentpageid "${NEW_BUILD_PAGE_ID}" \
  		--path "${results_path}"
done



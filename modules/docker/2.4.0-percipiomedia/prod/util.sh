#!/bin/bash

# Common shell functions for Percipiomedia Apache Ignite containers

LOG_DATE='date +%Y/%m/%d:%H:%M:%S'
LOG_FILE=${JOBCASE_LOGS}/entrypoint.log

#
# Append log message as INFO to log file .
#
function log_info {
  echo `$LOG_DATE`" INFO ${1}" | tee -a ${LOG_FILE}
}

#
# Append log message as ERROR to log fie.
#
function log_error {
  echo `$LOG_DATE`" ERROR ${1}" | tee -a ${LOG_FILE} 1>&2
}
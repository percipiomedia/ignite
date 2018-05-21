#!/bin/bash

# Adding user account for source code access 

source ./util.sh

function main() {
  local exit_code
  local result
  
  # check if user account already exists
  result=$(id -u "${USER_NAME}")
  
  exit_code=$?
  
  log_info "check user ${USER_NAME}: exit code ${exit_code} output ${result}"
  
  if [[ ${exit_code} -ne 0 ]]; then
    result=$(/usr/sbin/useradd --gid ${GROUP_ID} --uid ${USER_ID} --create-home ${USER_NAME})
  
    exit_code=$?
  
    log_info "adduser: exit code ${exit_code} output ${result}"
  fi
}

main
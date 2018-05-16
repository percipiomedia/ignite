#!/bin/bash

# Startup logic for Percipiomedia Apache Ignite containers

source ./util.sh

DEFAULT_JVM_OPTS='-Xms1g -Xmx1g -server -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC \
                  -XX:+DisableExplicitGC'

function usage() {

  echo "Usage: $0 OPTIONS"

  echo "OPTIONS:"
  
  echo "--help      | -h    Display this message"
  echo "--verbose   | -v    Verbose output"
  echo "--debug   | -d      Debug/Trace output"
  echo "--launch    | -l    Command to be executed"  

  exit 1
}

#
# Parse command line arguments.
#
function parse() {
  # Option strings
  local SHORT=h,v,d,l:
  local LONG=help,verbose,debug,launch:

  # read the options
  local OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

  if [ $? != 0 ] ; then log_error "Failed to parse options...exiting."; exit 1 ; fi

  eval set -- "$OPTS"

  # set initial values
  VERBOSE=false
  DEBUG=false
  LAUNCH_CMD=""

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
      -l | --launch )
        LAUNCH_CMD="$2"
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

#
# Main function of the shell script.
#
function main() {
  local result
  local cmd
  local commands
  local exit_code
  
  # dump environment into log file
  log_info "$(env)"
	
  # if conditions based on parsed command line arguments and environment variables
  # TODO
  if [ -n "${LAUNCH_CMD}" ]; then
    log_info "launch commands: ${LAUNCH_CMD}"
  
    # several launch commands are separarted by semicolon
    # semicolon (;) is set as delimiter
    IFS=';'      
      
    read -ra commands <<< "${LAUNCH_CMD}"    # str is read into an array as tokens separated by IFS
    
    for cmd in "${commands[@]}"; do    # access each element of array
      log_info "launch: $cmd"
      result=$("${cmd}")
      exit_code=$?
      log_info "launch result: exit code ${exit_code} output ${result}"
    done
    IFS=' '        # reset to default value after usage  
  fi	
  tail -f ${LOG_FILE}
}

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

main
#!/bin/bash

# Startup logic for Percipiomedia Apache Ignite containers

LOG_DATE='date +%Y/%m/%d:%H:%M:%S'
LOG_FILE=${JOBCASE_LOGS}/entrypoint.log

DEFAULT_JVM_OPTS='-Xms1g -Xmx1g -server -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC \
                  -XX:+DisableExplicitGC'


#
# Append entry to log file.
#
function log {
    echo `$LOG_DATE`" $1" >> ${LOG_FILE}
}

function usage() {

  echo "Usage: $0 OPTIONS"

  echo "OPTIONS:"
  
  echo "--help      | -h    Display this message"
  echo "--verbose   | -v    Verbose output"
  echo "--launch    | -l    Command to be executed"  

  exit 1
}

#
# Parse command line arguments.
#
function parse() {
  # Option strings
  local SHORT=h,v,l:
  local LONG=help,verbose,launch:

  # read the options
  local OPTS=$(getopt --options $SHORT --long $LONG --name "$0" -- "$@")

  if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi

  eval set -- "$OPTS"

  # set initial values
  VERBOSE=false

  # extract options and their arguments into variables.
  while true ; do
    case "$1" in
      -h | --help )
        usage;;
      -v | --verbose )
        VERBOSE=true
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
        echo "Incorrect parameter: $1"; usage;;
    esac
  done
}

#
# Main function of the shell script.
#
function main() {
    # dump environment into log file
	log "$(env)"

	log "VERBOSE=${VERBOSE}"
	
	# if conditions based on parsed command line arguments and environment variables
	# TODO
	
	
	tail -f ${LOG_FILE}
}

parse "$@"

main
#!/bin/bash

if [ "${OVERWRITE_POM_VERSION}" = "true" ]; then

  # Ignite defines following regular expression as valid version:
  #  private static final Pattern VER_PATTERN =
  #      Pattern.compile("(\\d+)\\.(\\d+)\\.(\\d+)([-.]([^0123456789][^-]+)(-SNAPSHOT)?)?(-(\\d+))?(-([\\da-f]+))?");

  # update <version>xxx</version> info in pom files with our build version
  echo ${WORKSPACE}
  echo ${BUILD_NUMBER}

  PREV_BUILD_NUMBER=$((BUILD_NUMBER-1))

  old="2.5.0-SNAPSHOT"
  oldbuild="2.5.0-${PREV_BUILD_NUMBER}"
  new="2.5.0-${BUILD_NUMBER}"

  echo "set version ${new} in all pom files"

  temp_file="repl.temp"

  for f in $(find . -name 'pom.xml' -type f); do

    result=$(cat ${f} | grep "${oldbuild}")
    exitCode=$?

    if [ ${exitCode} -eq 1 ]; then
      sed -e "s/<version>$old<\/version>/<version>$new<\/version>/" $f > $temp_file
    else
      sed -e "s/<version>$oldbuild<\/version>/<version>$new<\/version>/" $f > $temp_file
    fi

    mv $temp_file $f

    echo $f
  done
fi
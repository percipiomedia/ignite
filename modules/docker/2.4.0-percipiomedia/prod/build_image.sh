#!/bin/bash

rm -rf ./apache-ignite-fabric*

# copy maven build result into docker build path
cp ../../../../target/bin/apache-ignite-fabric-2.4.0-SNAPSHOT-bin.zip .

unzip apache-ignite-fabric-2.4.0-SNAPSHOT-bin.zip

# TODO artifactory integration
#docker login jobcase-platform-docker.jfrog.io --username mgay@jobcase.com --password AKCp5aTvLpKGbtqYyMpzXm9Gkq5E4TufZX5fuJvaCx9vmDgW9yScKrnYykBr2zvsN9XMjtFWW

sudo docker build -t apacheignite/percipiomedia:2.4.0 .
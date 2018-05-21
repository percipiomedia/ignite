#!/bin/bash

# TODO artifactory integration
#docker login jobcase-platform-docker.jfrog.io --username <name> --password <pwd>

sudo docker build -t apacheignite/percipiomedia-dev:2.4.0 .
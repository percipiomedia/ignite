# Percipiomedia Apache Ignite Production Docker Image

## Introduction

## Terminology

Docker Engine:
> *It is a client-server application with these major components:* 
> * *A server which is a type of long-running program called a daemon process (the dockerd command).* 
> * *A REST API which specifies interfaces that programs can use to talk to the daemon and instruct it what to do.* 
> * *A command line interface (CLI) client (the docker command).*

> *The daemon creates and manages Docker objects, such as images, containers, networks, and volumes.*

Docker Image: 
> *An image is an inert, immutable, file that’s essentially a snapshot of a container. Images are created with the build command, and they’ll produce a container when started with run.*

Docker Container:
> * A container is a runnable instance of an image. You can create, start, stop, move, or delete a container using the Docker API or CLI. You can connect a container to one or more networks, attach storage to it, or even create a new image based on its current state.*

## Build

~~~~
sudo docker build -t apacheignite/percipiomedia:2.4.0 .
~~~~


## Configuration



### Ports

Only one Ignite instance can run inside the docker container.
The docker image does not define port ranges.

The port values inside the container are:

~~~~
# Ports
ENV IGNITE_SERVER_PORT 11211
ENV IGNITE_JMX_PORT 49112
ENV IGNITE_DISCOVERY_PORT 47500
ENV IGNITE_COMMUNICATION_PORT 47100
ENV IGNITE_JDBC_PORT 10800
ENV IGNITE_REST_PORT 8080
~~~~

### Volumes

The docker image defines up-to four volumes.

~~~~
# JobCase home
ENV JOBCASE_HOME /opt/jobcase

# Location of configuration files
ENV JOBCASE_CONFIG ${JOBCASE_HOME}/config

# Location of container log files
ENV JOBCASE_LOGS ${JOBCASE_HOME}/logs

# root directory where Ignite will persist data, indexes and so on
ENV IGNITE_PERSISTANT_STORE ${JOBCASE_HOME}/db

# ip dicovery volume
ENV IGNITE_DISCOVERY /opt/jobcase/discovery
~~~~

If running the container locally on a development/test machine the log-, persistant- and discovery volumes should be mapped. E. g.

~~~~
sudo docker run -it
    -v /Users/mgay/ignite_nodes/logs:/opt/jobcase/logs
    -v /Users/mgay/ignite_nodes/db:/opt/jobcase/db
    -v /Users/mgay/ignite_nodes/discovery:/opt/jobcase/discovery
    --net=my-bridge -p 47100:47100 -p 47500:47500 -p 47808:8080
    --name=ignite-percipio apacheignite/percipiomedia:2.4.0 
~~~~

### Discovery

#### File
~~~~
    -e "CONFIG_URI=file:///opt/jobcase/config/file.discovery.node.config.xml"
~~~~


#### S3 Bucket
~~~~
    -e "CONFIG_URI=file:///opt/jobcase/config/s3bucket.discovery.node.config.xml"
~~~~

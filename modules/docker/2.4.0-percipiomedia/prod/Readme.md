# Percipiomedia Apache Ignite Production Docker Image

## Introduction

The docker images includes the Apache Ignite binaries V2.4. The binaries are built from GitHub https://github.com/percipiomedia/ignite.git branch ignite-2.4.

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

## References

* [1]: https://apacheignite.readme.io/docs/rest-api/ "Apache Ignite REST-API"
* [2]: https://docs.docker.com/engine/tutorials/networkingcontainers/ "Networking Containers"
* [3]: https://docs.docker.com/network/overlay/ "Overlay Networks"
* [4]: https://luppeng.wordpress.com/2018/01/03/revisit-setting-up-an-overlay-network-on-docker-without-docker-swarm/ "Overlay Network Without Swarm"

## Build

~~~~
sudo docker build -t apacheignite/percipiomedia:2.4.0 .
~~~~

## Networking

The Docker Engine supports different types of networks (bridge, overlay and host).
The default network type is bridge.
When Docker gets installed, a default network with the name bridge is created.

List available docker networks:

~~~~
sudo docker network ls
~~~~

Inspect default network bridge:

~~~~
sudo docker network inspect bridge

[
    {
        "Name": "bridge",
        "Id": "71310d36d398903889325ea029e728fad578293e829ee99d3fbab71a563530f3",
        "Created": "2018-05-18T11:02:54.005764144Z",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": null,
            "Config": [
                {
                    "Subnet": "172.17.0.0/16",
                    "Gateway": "172.17.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {
            "com.docker.network.bridge.default_bridge": "true",
            "com.docker.network.bridge.enable_icc": "true",
            "com.docker.network.bridge.enable_ip_masquerade": "true",
            "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
            "com.docker.network.bridge.name": "docker0",
            "com.docker.network.driver.mtu": "1500"
        },
        "Labels": {}
    }
]
~~~~

### Bridge Networks

The Docker Engine creates a network interface docker0 for the bridge network on the host. It allows network communication between the host and the docker containers attached to the bridge network.
**It does not apply to Mac OS X docker hosts (see appendix).**

A bridge network is limited to containers within a single host running the Docker engine.

It is recommend to create your own bridge network:

~~~~
docker network create
  --subnet 172.19.0.0/16
  --gateway 172.19.0.1
  my-bridge
~~~~

Attach specific network to container:

~~~~
sudo docker run -it
    --net=my-bridge
    --name=ignite-percipio apacheignite/percipiomedia:2.4.0 
~~~~

When attaching a container to a bridge network and it should be reachable from the outside world, port mapping needs to be configured.

### Overlay Networks

A overlay network ([documentation link][3]) allows network communication between containers on separate Docker engine hosts. It is used for so called multi-host network communication. 

Command for defining overlay network (using Swarm and standalone containers):

~~~~
docker network create -d overlay --attachable --subnet=192.168.10.0/24 my-overlay
~~~~

Please refer to [link][4] for setting up overlay network without Swarm.

## Configurationn



### Ports

Only one Ignite instance can run inside the docker container. The docker image does not define port ranges.

The default port values are:

~~~~
# Ports
ENV IGNITE_SERVER_PORT 11211
ENV IGNITE_JMX_PORT 49112
ENV IGNITE_DISCOVERY_PORT 47500
ENV IGNITE_COMMUNICATION_PORT 47100
ENV IGNITE_JDBC_PORT 10800
ENV IGNITE_REST_PORT 8080
~~~~

The defined port value(s) can be changed at container startup by passing environment variable.
E. g. `-e "IGNITE_DISCOVERY_PORT=48001"`. 


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
    --name=ignite-percipio apacheignite/percipiomedia:2.4.0 
~~~~

### Discovery

The docker image comes with Apache Ignite grid configuration files for two types of node discovery.

#### File

Start container with Apache Ignite file discovery:

~~~~
    -e "CONFIG_URI=file:///opt/jobcase/config/file.discovery.node.config.xml"
~~~~


#### S3 Bucket

Start container using S3 bucket node discovery:

~~~~
    -e "CONFIG_URI=file:///opt/jobcase/config/s3bucket.discovery.node.config.xml"
~~~~

### Ignite REST API

Apache Ignite supports REST protocol [link][1]. 

The API is accessible `http://<docker container ip>:8080/ignite?cmd=version`.
The default port value is `IGNITE_REST_PORT=80801`.

It can be overwritten by passing environment argument to the `docker run` command:

~~~~
    -e "IGNITE_REST_PORT=<port value>"
~~~~




## Appendix

### Mac OS X

#### Networking

TODO

#### Xterm Display

TODO
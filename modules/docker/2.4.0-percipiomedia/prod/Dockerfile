# Base image for Percipiomedia Apache Ignite

# Docker image layout:
#  |
#  - /opt/jobcase
#     |
#     | entrypoint.sh
#     |- logs
#     |- config
#     |- apache-ignite-fabric
#        |
#        | run.sh
#        |- bin
#        |- libs
#        |- config

# Start from a Java image.
FROM openjdk:8

# Ignite version
ENV IGNITE_VERSION 2.4.0

# Ports
ENV IGNITE_SERVER_PORT 11211
ENV IGNITE_JMX_PORT 49112
ENV IGNITE_DISCOVERY_PORT 47500
ENV IGNITE_COMMUNICATIONT_PORT 47100
ENV IGNITE_JDBC_PORT 10800
ENV IGNITE_REST_PORT 8080

# JobCase home
ENV JOBCASE_HOME /opt/jobcase

# Location of container log files
ENV JOBCASE_LOGS ${JOBCASE_HOME}/logs

# Ignite home
ENV IGNITE_HOME ${JOBCASE_HOME}/apache-ignite-fabric

# Do not rely on anything provided by base image(s), but be explicit, if they are installed already it is noop then
RUN apt-get update && apt-get install -y --no-install-recommends \
        unzip \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p ${JOBCASE_LOGS}
        
WORKDIR ${IGNITE_HOME}

# Copy apache ignite binaries
COPY ./apache-ignite-fabric-${IGNITE_VERSION}-SNAPSHOT-bin ${IGNITE_HOME}/

# Enable HTTP REST client
COPY ./apache-ignite-fabric-${IGNITE_VERSION}-SNAPSHOT-bin/libs/optional/ignite-rest-http ${IGNITE_HOME}/libs/ignite-rest-http/

# Copy REST client configuration file
COPY ./jetty-config.xml ${JOBCASE_HOME}/

# Copy sh files and set permission
COPY ./run.sh ${IGNITE_HOME}/

RUN chmod +x ${IGNITE_HOME}/run.sh

# The entrypoint.sh script is always executed at container startup.
# It includes the logic for further runtime configuration and/or operations.
COPY ./entrypoint.sh ${JOBCASE_HOME}/
RUN chmod +x ${JOBCASE_HOME}/entrypoint.sh

ENTRYPOINT /bin/bash ${JOBCASE_HOME}/entrypoint.sh

# Set default arguments for ENTRYPOINT
CMD ["--launch", ${IGNITE_HOME}/run.sh]

EXPOSE $IGNITE_SERVER_PORT $IGNITE_COMMUNICATIONT_PORT $IGNITE_DISCOVERY_PORT $IGNITE_JMX_PORT $IGNITE_JDBC_PORT $IGNITE_REST_PORT
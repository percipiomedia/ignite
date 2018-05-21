# Developer image for Percipiomedia Apache Ignite

# It includes maven, eclipse and latest source code.

# Start from Percipiomedia Apache Ignite base image
FROM apacheignite/percipiomedia:2.4.0

# Eclipse tar archive
ARG ELCIPSE_TAR=eclipse-jee-oxygen-3a-linux-gtk-x86_64.tar.gz

# Maven version
ARG MAVEN_VERSION=3.5.3

# The specified user account is used for cloning the GIT repository 
# and creating the Eclipse workspace.
# It is recommend to pass-in the Mac OS X user account instead of using root.
ENV USER_ID=0
ENV GROUP_ID=0
ENV USER_NAME=root
 
# Do not rely on anything provided by base image(s), but be explicit, if they are installed already it is noop then
RUN apt-get update && apt-get install -y --no-install-recommends \
        unzip \
        sudo \
# Install nmap for troubleshooting network communication                 
        nmap \        
    && rm -rf /var/lib/apt/lists/* \
# Install Maven
    && curl http://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz -N -o /tmp/maven.tar.gz -q \
    && cd /tmp \
    && tar -xf maven.tar.gz -C /opt \
    && rm /tmp/maven.tar.gz \
# Install Eclipse    
    && curl http://mirror.math.princeton.edu/pub/eclipse/technology/epp/downloads/release/oxygen/3a/${ELCIPSE_TAR} -N -o /tmp/eclipse.tar.gz \
    && tar -xf eclipse.tar.gz -C /opt \
    && rm /tmp/eclipse.tar.gz

# Copy adduser.sh script    
COPY ./adduser.sh ${JOBCASE_HOME}/
RUN chmod +x ${JOBCASE_HOME}/adduser.sh

# TODO
# - Add git clone of https://github.com/percipiomedia/ignite.git
# - Create eclipse workspace
# - Import jobcase.epf with code formatting to eclipse workspace
    
# Copy grid configuration file
COPY ./node.config.xml ${JOBCASE_HOME}/

# Copy 
COPY ./nmap_commands.sh ${JOBCASE_HOME}/

# Set default arguments for ENTRYPOINT
#"--useradd", "${USER_NAME}:${USER_ID}:${GROUP_ID}"
CMD ["--develop", "--launch", "./adduser.sh;/opt/eclipse/eclipse &"]
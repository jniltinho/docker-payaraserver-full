FROM rockylinux:8

## https://github.com/payara/docker-payaraserver-full/blob/master/Dockerfile
# docker build --no-cache -t rockylinux-payaraserver .
# docker run -d --name payara -p 4848:4848 -p 8080:8080 -p 8181:8181 rockylinux-payaraserver

# Default payara ports to expose
# 4848: admin console
# 9009: debug port (JPDA)
# 8080: http
# 8181: https
EXPOSE 4848 9009 8080 8181

# Payara version (5.2022+)
ARG PAYARA_VERSION=5.2022.3
ARG PAYARA_PKG=https://search.maven.org/remotecontent?filepath=fish/payara/distributions/payara/${PAYARA_VERSION}/payara-${PAYARA_VERSION}.zip
ARG TINI_VERSION=v0.19.0

# Initialize the configurable environment variables
ENV HOME_DIR=/opt/payara\
    PAYARA_DIR=/opt/payara/appserver\
    SCRIPT_DIR=/opt/payara/scripts\
    CONFIG_DIR=/opt/payara/config\
    DEPLOY_DIR=/opt/payara/deployments\
    PASSWORD_FILE=/opt/payara/passwordFile\
    # Payara Server Domain options
    DOMAIN_NAME=domain1\
    ADMIN_USER=admin\
    ADMIN_PASSWORD=admin \
    # Utility environment variables
    JVM_ARGS=\
    PAYARA_ARGS=\
    DEPLOY_PROPS=\
    POSTBOOT_COMMANDS=/opt/payara/config/post-boot-commands.asadmin\
    PREBOOT_COMMANDS=/opt/payara/config/pre-boot-commands.asadmin
ENV PATH="${PATH}:${PAYARA_DIR}/bin"

# Create and set the Payara user and working directory owned by the new user
RUN groupadd -g 1000 payara && \
    useradd -u 1000 -M -s /bin/bash -d ${HOME_DIR} payara -g payara && \
    echo payara:payara | chpasswd && \
    mkdir -p ${DEPLOY_DIR}; mkdir -p ${SCRIPT_DIR} ${CONFIG_DIR}; chown -R payara: ${HOME_DIR} \
    # Install required packages
    && yum install --nogpgcheck -y curl unzip java-11-openjdk-headless \
    && yum clean all && rm -rf /tmp/yum*

# Install tini as minimized init system
RUN curl -skL -o /tini https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini && chmod +x /tini

USER payara
WORKDIR ${HOME_DIR}

# Download and unzip the Payara distribution
RUN curl -skL -o payara.zip ${PAYARA_PKG} && \
    unzip -qq payara.zip -d ./; mv payara*/ appserver && \
    # Configure the password file for configuring Payara
    echo -e "AS_ADMIN_PASSWORD=\nAS_ADMIN_NEWPASSWORD=${ADMIN_PASSWORD}" > /tmp/tmpfile && \
    echo "AS_ADMIN_PASSWORD=${ADMIN_PASSWORD}" >> ${PASSWORD_FILE} && \
    # Configure the payara domain
    asadmin --user=${ADMIN_USER} --passwordfile=/tmp/tmpfile change-admin-password --domain_name=${DOMAIN_NAME} && \
    asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} start-domain ${DOMAIN_NAME} && \
    asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} enable-secure-admin && \
    asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} set-log-attributes com.sun.enterprise.server.logging.GFFileHandler.logtoFile=false && \
    asadmin --user=${ADMIN_USER} --passwordfile=${PASSWORD_FILE} stop-domain ${DOMAIN_NAME} && \
    # Cleanup unused files
    rm -rf /tmp/tmpFile payara.zip \
    ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/osgi-cache ${PAYARA_DIR}/glassfish/domains/${DOMAIN_NAME}/logs
    #${PAYARA_DIR}/glassfish/domains/domain1

# Copy across docker scripts
COPY --chown=payara:payara bin/*.sh ${SCRIPT_DIR}/
RUN mkdir -p ${SCRIPT_DIR}/init.d && chmod +x ${SCRIPT_DIR}/*

ENTRYPOINT ["/tini", "--"]
CMD ${SCRIPT_DIR}/entrypoint.sh

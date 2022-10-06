FROM rockylinux:8

## https://github.com/payara/docker-payaraserver-full/blob/master/Dockerfile
## https://www.osradar.com/how-to-install-payara-server-on-ubuntu-18-04/
## https://techviewleo.com/install-eclipse-glassfish-on-rocky-linux-centos/
## https://www.centlinux.com/2019/05/install-payara-server-5-on-centos-7.html

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
RUN groupadd -g 1000 payara; useradd -u 1000 -M -s /bin/bash -d ${HOME_DIR} payara -g payara; echo payara:payara | chpasswd \
    && mkdir -p ${DEPLOY_DIR} ${SCRIPT_DIR} ${CONFIG_DIR}; chown -R payara: ${HOME_DIR} \
    # Install required packages
    && yum install --nogpgcheck -y curl unzip java-11-openjdk-headless; yum clean all && rm -rf /tmp/yum*


## https://github.com/ochinchina/supervisord
COPY --from=ochinchina/supervisord:latest /usr/local/bin/supervisord /usr/local/bin/supervisord

RUN curl -skLO https://github.com/upx/upx/releases/download/v3.96/upx-3.96-amd64_linux.tar.xz \
    && tar -xf upx-*.tar.xz; mv upx-*/upx /usr/local/bin/; rm -rf upx-3.* \
    && upx --best --lzma /usr/local/bin/supervisord

USER payara
WORKDIR ${HOME_DIR}

# Download and unzip the Payara distribution
RUN curl -skL -o payara.zip ${PAYARA_PKG} && unzip -qq payara.zip -d ./; mv payara*/ appserver && \
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

# Copy across docker scripts
COPY container-files /
ENTRYPOINT ["/config/bootstrap.sh"]

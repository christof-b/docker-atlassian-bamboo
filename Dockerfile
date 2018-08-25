FROM openjdk:8-alpine

# Setup useful environment variables
ENV BAMBOO_HOME     /var/atlassian/bamboo
ENV BAMBOO_INSTALL  /opt/atlassian/bamboo
ENV BAMBOO_VERSION  6.6.1

ENV TZ			  CET-2CEDT-2

# Install Atlassian Bamboo and helper tools and setup initial home
# directory structure.
RUN set -x \
	&& echo ${TZ} > /etc/TZ \
	&& apk update \
    && apk add --no-cache curl xmlstarlet git openssh bash ttf-dejavu libc6-compat apr-util apr-dev openssl openssl-dev gcc musl-dev make \
    && mkdir -p               "${BAMBOO_HOME}/lib" \
    && mkdir -p               "${BAMBOO_INSTALL}" \
    && curl -Ls               "https://www.atlassian.com/software/bamboo/downloads/binary/atlassian-bamboo-${BAMBOO_VERSION}.tar.gz" | tar -zx --directory  "${BAMBOO_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                "https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.40.tar.gz" | tar -xz --directory "${BAMBOO_INSTALL}/lib" --strip-components=1 --no-same-owner "mysql-connector-java-5.1.40/mysql-connector-java-5.1.40-bin.jar" \
    && sed --in-place         's/^# umask 0027$/umask 0027/g' "${BAMBOO_INSTALL}/bin/setenv.sh" \
    && xmlstarlet             ed --inplace \
        --delete              "Server/Service/Engine/Host/@xmlValidation" \
        --delete              "Server/Service/Engine/Host/@xmlNamespaceAware" \
                              "${BAMBOO_INSTALL}/conf/server.xml" \
    && touch -d "@0"          "${BAMBOO_INSTALL}/conf/server.xml" \
    && tar -xzvf ${BAMBOO_INSTALL}/bin/tomcat-native.tar.gz -C /tmp \
    && cd /tmp/tomcat-native-1.2.7-src/native && ./configure --with-apr=/usr/bin/apr-1-config --with-java-home=/usr/lib/jvm/java-1.8-openjdk --with-ssl=yes --prefix=/usr && make && make install \
    && rm -r -f /tmp/tomcat-native-1.2.7-src \
    && apk del apr-dev openssl-dev gcc musl-dev make


# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
RUN set -x \
	&& adduser -D -G root -g "ROS User" rosuser \
    && chmod -R 770           "${BAMBOO_HOME}" \
    && chown -R rosuser:root  "${BAMBOO_HOME}" \
    && chmod -R 770            "${BAMBOO_INSTALL}" \
    && chown -R rosuser:root  "${BAMBOO_INSTALL}" 

USER rosuser
    
    
# Expose default HTTP and SSH ports.
EXPOSE 8085 54663

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs. Index folder should be mounted manually, because of issues with NFS.
VOLUME ["/var/atlassian/bamboo", "/opt/atlassian/bamboo/logs"]

# Set the default working directory as the Bamboo home directory.
WORKDIR /var/atlassian/bamboo

COPY "docker-entrypoint.sh" "/"
ENTRYPOINT ["/docker-entrypoint.sh"]

# Run Atlassian Bamboo as a foreground process by default.
CMD ["/opt/atlassian/bamboo/bin/start-bamboo.sh", "-fg"]

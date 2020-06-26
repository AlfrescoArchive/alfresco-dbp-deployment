FROM alfresco/alfresco-content-repository:6.2.2-RC2

ARG GROUPNAME=Alfresco
ARG USERNAME=alfresco
ARG TOMCAT_DIR=/usr/local/tomcat

# Switch from 'alfresco' user to 'root', to avoid Permission denied error.
USER root

# Copy DBP AMPs into 'dbp' fir to avoid reinstalling the existing AMPs
# Also, change ownership to be the same as the base image.
COPY --chown=root:${GROUPNAME} target/amps ${TOMCAT_DIR}/amps/dbp

COPY --chown=root:${GROUPNAME} saml ${TOMCAT_DIR}/keystore

# After applying AMPs, change the group and mod of the added files and directories from the AMPs,
# to be the same as the base image settings.
RUN java -jar ${TOMCAT_DIR}/alfresco-mmt/alfresco-mmt*.jar install \
        ${TOMCAT_DIR}/amps/dbp ${TOMCAT_DIR}/webapps/alfresco -directory -nobackup && \
        chgrp -R ${GROUPNAME} ${TOMCAT_DIR} && \
        find ${TOMCAT_DIR}/webapps -type d -exec chmod 0750 {} \; && \
        find ${TOMCAT_DIR}/webapps -type f -exec chmod 0640 {} \; && \
        find ${TOMCAT_DIR}/keystore -type d -exec chmod 0750 {} \; && \
        find ${TOMCAT_DIR}/keystore -type f -exec chmod 0640 {} \; && \
        chmod -R g+r ${TOMCAT_DIR}/webapps

# Switch back to 'alfresco' user
USER ${USERNAME}

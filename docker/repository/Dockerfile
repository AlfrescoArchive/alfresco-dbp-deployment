FROM alfresco/alfresco-content-repository:6.1.1-RC1

# TODO DEPLOY-827

ARG GROUPNAME=Alfresco
ARG TOMCAT_DIR=/usr/local/tomcat
ARG USERNAME=alfresco

# Switch from 'alfresco' user to 'root', to avoid Permission denied error.
USER root

# Create a directory to avoid reinstalling the existing AMPs
# and change its ownership.
RUN mkdir -p ${TOMCAT_DIR}/amps/dbp && \
    chgrp ${GROUPNAME} ${TOMCAT_DIR}/amps/dbp

# Add DBP AMPs and change ownership to be the same as the base image.
# Note: 
# Docker version on Bamboo elastic agents is 18.09.3, which doesn't support argument substitution.
# When DELENG-679 gets fixed we should change the COPY command to:
# COPY --chown=root:${GROUPNAME} target/amps ${TOMCAT_DIR}/amps/dbp
COPY --chown=root:Alfresco target/amps ${TOMCAT_DIR}/amps/dbp

# Same as the above, when DELENG-679 gets fixed we should change the COPY command to:
# COPY --chown=root:${GROUPNAME} saml /opt/saml
COPY --chown=root:Alfresco saml /opt/saml

# After applying AMPs, change the group and mod of the added files and directories from the AMPs, 
# to be the same as the base image settings.
RUN java -jar ${TOMCAT_DIR}/alfresco-mmt/alfresco-mmt*.jar install \
        ${TOMCAT_DIR}/amps/dbp ${TOMCAT_DIR}/webapps/alfresco -directory -nobackup && \
        chgrp -R ${GROUPNAME} ${TOMCAT_DIR}/webapps/alfresco && \
        find ${TOMCAT_DIR}/webapps/alfresco -type d -exec chmod 0750 {} \; && \
        find ${TOMCAT_DIR}/webapps/alfresco -type f -exec chmod 0640 {} \; 

# Switch back to 'alfresco' user
USER ${USERNAME}

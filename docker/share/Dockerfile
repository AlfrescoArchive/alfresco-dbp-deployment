FROM alfresco/alfresco-share:6.2.2

ARG TOMCAT_DIR=/usr/local/tomcat

# Copy DBP AMPs into 'dbp' fir to avoid reinstalling the existing AMPs
COPY target/amps ${TOMCAT_DIR}/amps_share/dbp

RUN java -jar ${TOMCAT_DIR}/alfresco-mmt/alfresco-mmt*.jar install \
       ${TOMCAT_DIR}/amps_share/dbp ${TOMCAT_DIR}/webapps/share -directory -nobackup

COPY saml/saml-config.sh ${TOMCAT_DIR}/shared/classes/alfresco

RUN chmod +x ${TOMCAT_DIR}/shared/classes/alfresco/saml-config.sh && \
    ${TOMCAT_DIR}/shared/classes/alfresco/saml-config.sh

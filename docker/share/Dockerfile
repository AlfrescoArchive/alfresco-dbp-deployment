FROM alfresco/alfresco-share:6.2.0-RC4

ARG TOMCAT_DIR=/usr/local/tomcat

# Copy DBP AMPs into 'dbp' fir to avoid reinstalling the existing AMPs
COPY target/amps ${TOMCAT_DIR}/amps_share/dbp

RUN java -jar ${TOMCAT_DIR}/alfresco-mmt/alfresco-mmt*.jar install \
       ${TOMCAT_DIR}/amps_share/dbp ${TOMCAT_DIR}/webapps/share -directory -nobackup

# We don't need these for kerberos
#COPY saml/saml-config.sh ${TOMCAT_DIR}/shared/classes/alfresco
#RUN chmod +x ${TOMCAT_DIR}/shared/classes/alfresco/saml-config.sh && \
#    ${TOMCAT_DIR}/shared/classes/alfresco/saml-config.sh

FROM alfresco/alfresco-content-repository:6.1.0

# Add DBP AMPs
COPY target/amps /usr/local/tomcat/amps

COPY saml /opt/saml

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
        /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup

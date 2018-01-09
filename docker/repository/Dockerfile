FROM docker-internal.alfresco.com/full-content-services:latest

# Remove Share installed by the ACS image
# TODO: Remove this once the Repo team update their image
RUN rm -r /usr/local/tomcat/webapps/share

# Add DBP AMPs
COPY target/amps /usr/local/tomcat/amps

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
        /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup

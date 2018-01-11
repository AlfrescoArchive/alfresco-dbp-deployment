FROM quay.io/alfresco/alfresco-full-share:5.2.X

# Add DBP AMPs
COPY target/amps /usr/local/tomcat/amps_share

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
        /usr/local/tomcat/amps_share /usr/local/tomcat/webapps/share -directory -nobackup

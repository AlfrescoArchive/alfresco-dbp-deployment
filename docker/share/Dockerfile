FROM alfresco/alfresco-share:6.1.1-RC1

# Add DBP AMPs
COPY target/amps /usr/local/tomcat/amps_share

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
       /usr/local/tomcat/amps_share /usr/local/tomcat/webapps/share -directory -nobackup

COPY saml/saml-config.sh /usr/local/tomcat/shared/classes/alfresco
RUN chmod +x /usr/local/tomcat/shared/classes/alfresco/saml-config.sh
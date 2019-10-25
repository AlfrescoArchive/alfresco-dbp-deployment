FROM alfresco/alfresco-share:6.1.1

# Create a directory to avoid reinstalling the existing AMPs
RUN mkdir -p /usr/local/tomcat/amps_share/dbp

# Add DBP AMPs
COPY target/amps /usr/local/tomcat/amps_share/dbp

RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
       /usr/local/tomcat/amps_share/dbp /usr/local/tomcat/webapps/share -directory -nobackup

# We don't need these for kerberos
# COPY saml/saml-config.sh /usr/local/tomcat/shared/classes/alfresco
# RUN chmod +x /usr/local/tomcat/shared/classes/alfresco/saml-config.sh && \
#     /usr/local/tomcat/shared/classes/alfresco/saml-config.sh
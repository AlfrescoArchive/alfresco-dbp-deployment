FROM quay.io/alfresco/alfresco-base-tomcat:0.1.0

# Docker layerization is procedural. This means that each directive is a layer, executed in the sequence in which it is presented.
# If a layer changes, it invalidates all subsequent layers.
# The EXPOSE, CMD and ENV layers are the ones least likely to change and they normally remain on top to reduce build time.
EXPOSE 8080
CMD ["/root/entrypoint.sh"]

ENV CATALINA_HOME /usr/local/tomcat
ENV ACTIVITI_APP_PROPS ${CATALINA_HOME}/lib/activiti-app.properties

ENV ACTIVITI_VERSION 1.8.0

COPY download_assets.sh /root/download_assets.sh
COPY activiti-app.war ${CATALINA_HOME}/webapps/activiti-app.war
# Download the activiti-app.war (versioned) and the postgresql-connector
RUN chmod +x /root/download_assets.sh && \
  /root/download_assets.sh && \
  rm /root/download_assets.sh

# Copy custom entrypoint and properties
COPY set-activiti-config.sh entrypoint.sh /root/
COPY docker-activiti-app.properties ${ACTIVITI_APP_PROPS}

RUN chmod +x /root/set-activiti-config.sh && \
  chmod +x /root/entrypoint.sh
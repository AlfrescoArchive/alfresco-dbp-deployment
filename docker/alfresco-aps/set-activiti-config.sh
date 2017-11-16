#!/bin/bash

properties=$ACTIVITI_APP_PROPS

if [ -n "$EXTERNAL_PROPERTIES_FILE" ]
then
  echo "Using external config file"
  curl $EXTERNAL_PROPERTIES_FILE -o $ACTIVITI_APP_PROPS
elif [ -n "$S3_BUCKET_WITH_ROLE" ]
then
  echo "Trying to fetch the properties from the bucket $BUCKET_NAME"
  $HOME/get_from_s3.sh $EXTERNAL_PROPERTIES_OBJECT_NAME $BUCKET_NAME
else
  echo "Using normal config file"
  test -n "$ACTIVITI_LICENSE_MULTI_TENANT" && sed -i "s|^\(license\.multi\-tenant\s*=\s*\).*\$|\1$ACTIVITI_LICENSE_MULTI_TENANT|" $properties
  test -n "$ACTIVITI_DATASOURCE_URL" && sed -i "s|^\(datasource\.url\s*=\s*\).*\$|\1$ACTIVITI_DATASOURCE_URL|" $properties
  test -n "$ACTIVITI_DATASOURCE_DRIVER" && sed -i "s/^\(datasource\.driver\s*=\s*\).*\$/\1$ACTIVITI_DATASOURCE_DRIVER/" $properties
  test -n "$ACTIVITI_DATASOURCE_USERNAME" && sed -i "s/^\(datasource\.username\s*=\s*\).*\$/\1$ACTIVITI_DATASOURCE_USERNAME/" $properties
  test -n "$ACTIVITI_DATASOURCE_PASSWORD" && sed -i "s/^\(datasource\.password\s*=\s*\).*\$/\1$ACTIVITI_DATASOURCE_PASSWORD/" $properties
  test -n "$ACTIVITI_HIBERNATE_DIALECT" && sed -i "s/^\(hibernate\.dialect\s*=\s*\).*\$/\1$ACTIVITI_HIBERNATE_DIALECT/" $properties
  test -n "$ACTIVITI_ADMIN_EMAIL" && sed -i "s/^\(admin\.email\s*=\s*\).*\$/\1$ACTIVITI_ADMIN_EMAIL/" $properties
  test -n "$ACTIVITI_ADMIN_PASSWORD_HASH" && sed -i "s/^\(admin\.passwordHash\s*=\s*\).*\$/\1$ACTIVITI_ADMIN_PASSWORD_HASH/" $properties
  test -n "$ACTIVITI_ES_SERVER_TYPE" && sed -i "s/^\(elastic\-search\.server\.type\s*=\s*\).*\$/\1$ACTIVITI_ES_SERVER_TYPE/" $properties
  test -n "$ACTIVITI_ES_DISCOVERY_HOSTS" && sed -i "s/^\(elastic\-search\.discovery\.hosts\s*=\s*\).*\$/\1$ACTIVITI_ES_DISCOVERY_HOSTS/" $properties
  test -n "$ACTIVITI_ES_CLUSTER_NAME" && sed -i "s/^\(elastic\-search\.cluster\.name\s*=\s*\).*\$/\1$ACTIVITI_ES_CLUSTER_NAME/" $properties
  test -n "$ACTIVITI_CORS_ENABLED" && sed -i "s/^\(cors\.enabled\s*=\s*\).*\$/\1$ACTIVITI_CORS_ENABLED/" $properties
  test -n "$ACTIVITI_CORS_ALLOWED_ORIGINS" && sed -i "s/^\(cors\.allowed\.origins\s*=\s*\).*\$/\1$ACTIVITI_CORS_ALLOWED_ORIGINS/" $properties
  test -n "$ACTIVITI_CORS_ALLOWED_METHODS" && sed -i "s/^\(cors\.allowed\.methods\s*=\s*\).*\$/\1$ACTIVITI_CORS_ALLOWED_METHODS/" $properties
  test -n "$ACTIVITI_CORS_ALLOWED_HEADERS" && sed -i "s/^\(cors\.allowed\.headers\s*=\s*\).*\$/\1$ACTIVITI_CORS_ALLOWED_HEADERS/" $properties
  test -n "$ACTIVITI_CSRF_DISABLED" && sed -i "s/^\(security\.csrf\.disabled\s*=\s*\).*\$/\1$ACTIVITI_CSRF_DISABLED/" $properties
fi
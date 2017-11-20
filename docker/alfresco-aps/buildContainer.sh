#!/bin/bash
set -o errexit

. ./build.properties

mvn org.apache.maven.plugins:maven-dependency-plugin:2.8:copy \
    -Dartifact=$APS_MAVEN_GROUP_ID:$APS_MAVEN_ARTIFACT_ID:$APS_MAVEN_VERSION \
    -DoutputDirectory=./
# get activiti.war from https://bamboo.alfresco.com/bamboo/browse/ACT-ABS239

docker build . -t quay.io/alfresco-aps:$APS_MAVEN_VERSION
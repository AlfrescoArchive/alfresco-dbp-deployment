#!/bin/bash
set -o errexit

. ./build.properties

echo "Downloading required AMPs..."
if [[ "$bamboo_capability_system_builder_mvn3_Maven_3_3" == "" ]]; then
	mvn clean package
else
    $bamboo_capability_system_builder_mvn3_Maven_3_3/bin/mvn clean package
fi

echo "Building image ($DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG)..."
docker build -t quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG .
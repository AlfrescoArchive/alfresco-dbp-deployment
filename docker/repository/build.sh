#!/bin/bash
set -o errexit

. ./build.properties

if [ -d ./target ]; then
    echo "Required AMPs already present!"
else
    echo "Downloading required AMPs..."
    mvn clean package
fi

echo "Building image ($DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG)..."
docker build -t quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG .
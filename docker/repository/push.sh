#!/bin/sh
set -o errexit

. ./build.properties

echo "Pushing image..."
docker push quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG
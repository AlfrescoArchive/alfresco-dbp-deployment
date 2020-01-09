#!/bin/sh
set -o errexit

. ./build.properties

if [ ! -z "$BRANCH_NAME" -a "$BRANCH_NAME" != "master" ]
then
  DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG}-${BRANCH_NAME}"
fi

echo "Pushing image..."
docker push quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG

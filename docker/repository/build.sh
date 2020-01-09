#!/bin/bash
set -o errexit

. ./build.properties

# To support local and Bamboo builds only call mvn when the target folder is missing.
# To do a full clean build locally run "mvn clean" before running this script.

if [ -d ./target ]; then
    echo "Required AMPs already present!"
else
    echo "Downloading required AMPs..."
    mvn clean package
fi

if [ ! -z "$BRANCH_NAME" -a "$BRANCH_NAME" != "master" -a "$BRANCH_NAME" != "1.6.x" -a "$BRANCH_NAME" != "develop" ]
then
  DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG}-${BRANCH_NAME}"
fi

echo "Building image ($DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG)..."
#docker build -t quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG .

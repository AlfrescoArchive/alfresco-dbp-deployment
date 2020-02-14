#!/bin/bash

EXPIRE_AFTER="${EXPIRE_AFTER:-2w}"

function build_image() {
    # To support local and Bamboo builds only call mvn when the target folder is missing.
    # To do a full clean build locally run "mvn clean" before running this script.

    if [ -d ./target ]; then
        echo "Required AMPs already present!"
    else
        echo "Downloading required AMPs..."
        mvn clean package
    fi

    EXPIRES_AFTER_LABEL=""
    if [ ! -z "$BRANCH_NAME" -a "$BRANCH_NAME" != "master" -a "$BRANCH_NAME" != "1.6.x" -a "$BRANCH_NAME" != "develop" ]; then
        DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG}-${BRANCH_NAME}"
        # Add expiration label so it can be deleted by quay automatically
        EXPIRES_AFTER_LABEL="--label quay.expires-after=$EXPIRE_AFTER"
    fi

    if [ -z "$EXPIRES_AFTER_LABEL" ]; then
        echo "Building image ($DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG)..."
    else
        echo "Building image ($DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG) with label: '$EXPIRES_AFTER_LABEL'..."
    fi
    docker build -t quay.io/alfresco/$DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG . $EXPIRES_AFTER_LABEL
}

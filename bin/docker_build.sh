#!/usr/bin/env bash

set -x # for debugging
# set -e

# docker build job with semantic versioning

# steps required

# find version by project type
# determine if version is replaceable
# if release version determine if it already exists
#     true: FAIL false: continue

# run publish test
# if publish test succeeds, tag container and push to registry

DEBUG_PREFIX="echo" # for debugging
BIN_DIR=$(dirname "$0")

DOCKER_OPTIONS=${DOCKER_OPTIONS:-}
DOCKER_REPO=${DOCKER_REPO:-}

CONTAINER_PUSH=NO
CONTAINER_TAGS=""
CONTAINER_BUILD_CONTEXT=${CONTAINER_BUILD_CONTEXT:-.}
CONTAINER_BUILD_TAG="$JOB_BASE_NAME-$BUILD_NUMBER"  #  these vars supplied by Jenkins
CONTAINER_BUILD_NAME=$DOCKER_REPO:$CONTAINER_BUILD_TAG

PROJECT_BRANCH=${PROJECT_BRANCH:-$(git branch | grep -oP '\*\s\K.*$')}
PROJECT_VERSION=$(bash ${BIN_DIR}/get_version.sh ${CONTAINER_BUILD_CONTEXT})

CONTAINER_VERSION_NAME=$DOCKER_REPO:$PROJECT_VERSION


function container_build() {
    $DEBUG_PREFIX docker build $DOCKER_OPTIONS \
        -t $CONTAINER_BUILD_NAME \
        --build-arg VERSION=$PRODUCT_VERSION \
        $CONTAINER_BUILD_CONTEXT
}


function main() {
  container_build  
}

env
main

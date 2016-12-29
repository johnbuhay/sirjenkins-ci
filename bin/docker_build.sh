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

# DEBUG_PREFIX="echo" # for debugging
BIN_DIR=$(dirname "$0")
BUILD_ARGS=""

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
        $BUILD_ARGS \
        $CONTAINER_BUILD_CONTEXT
}


function cleanup() {
    echo 'Stopped Containers'
    docker ps -a --filter "status=exited"

    echo Deleting just built container
    docker rmi $CONTAINER_BUILD_NAME || true

    echo Deleting stopped containers
    docker rm -v $(docker ps -a -q --no-trunc --filter "status=exited") || true

    echo Deleting dangling images
    docker rmi $(docker images -q --no-trunc --filter "dangling=true") || true

    echo Deleting dangling volumes
    docker volume rm $(docker volume ls -q --filter "dangling=true") || true

    echo Running containers are
    docker ps

    echo Remaining images are
    docker images
}


function main() {
    validate_vars
    container_build  
}


function semver_build() {
    if docker pull $CONTAINER_VERSION_NAME; then
        if echo $PRODUCT_VERSION | grep -qP "\-(\d+|SNAPSHOT)"; then
            build_container
        else
            echo Skipping docker build because container $CONTAINER_VERSION_NAME already exists
            CONTAINER_ID=$(docker inspect --format='{{.Id}}' $CONTAINER_VERSION_NAME)
        fi
    else
        build_container
    fi
}


function validate_vars() {
    if [ -z "$DOCKER_REPO" ]; then
        echo "No DOCKER_REPO specified!"
        exit 1
    fi

    if [ -z "$PROJECT_BRANCH" ]; then
        echo "No BRANCH specified!"
        exit 1
    fi

    if [ -z "$PROJECT_VERSION" ]; then
        echo "No PROJECT_VERSION found!"
        exit 1
    fi

    if grep -q 'ARG VERSION' ${CONTAINER_BUILD_CONTEXT}/Dockerfile; then
        BUILD_ARGS="--build-arg VERSION=$PROJECT_VERSION"
    fi
}


env
main
cleanup

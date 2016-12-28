#!/usr/bin/env bash

BIN_DIR=$(dirname "$0")

if [ "$BUILD_TYPE" == 'docker' ]; then
    exec bash $BIN_DIR/docker_build.sh
else
    echo "Build type set to $BUILD_TYPE"
    exit 1
fi

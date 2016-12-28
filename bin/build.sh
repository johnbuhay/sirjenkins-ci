#!/usr/bin/env bash

BIN_DIR=ci/bin

if [ "$BUILD_TYPE" == 'docker' ]; then
    exec bash $BIN_DIR/docker_build.sh
else
    echo "Build type set to $BUILD_TYPE"
fi

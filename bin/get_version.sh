#!/usr/bin/env bash

VERSION_DIR=$(dirname "$0")/version

[ ! -z "$1" ] && cd $1
test -e package.json && exec python ${WORKSPACE:-.}/$VERSION_DIR/node.py
test -e version.txt && exec bash ${WORKSPACE:-.}/$VERSION_DIR/default.sh

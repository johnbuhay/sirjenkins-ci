#!/usr/bin/env bash

VERSION_DIR=$(dirname "$0")/version

test -e package.json && exec python $VERSION_DIR/node.py
test -e version.txt && exec bash $VERSION_DIR/default.sh

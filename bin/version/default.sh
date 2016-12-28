#!/usr/bin/env bash

[ ! -z "$1" ] && cd $1
test -r version.txt && cat version.txt

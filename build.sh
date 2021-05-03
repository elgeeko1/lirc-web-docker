#!/usr/bin/env bash

set -e

# enable docker BuildKit features
export DOCKER_BUILDKIT=1

docker build . --build-arg BUILDKIT_INLINE_CACHE=1 $@

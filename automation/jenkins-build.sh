#!/bin/bash
set -e

VERSION=$(git rev-parse --short HEAD)
ESCAPED_BRANCH_NAME=$(echo $sourceBranch | sed 's/[^a-z0-9A-Z_.-]/-/g')
IGNORE_CACHE=${IGNORE_CACHE:-0}

if [ "$IGNORE_CACHE" == "true" ]; then
	docker build --pull --no-cache --tag resin/${JOB_NAME}:${VERSION} .
else
	# Try pulling the old build first for caching purposes.
	docker pull resin/${JOB_NAME}:${ESCAPED_BRANCH_NAME} || docker pull resin/${JOB_NAME}:master || true

	docker build --tag resin/${JOB_NAME}:${VERSION} .
fi

docker tag -f resin/${JOB_NAME}:${VERSION} resin/${JOB_NAME}:${ESCAPED_BRANCH_NAME}
docker tag -f resin/${JOB_NAME}:${VERSION} resin/${JOB_NAME}:latest

# Push the images
docker push resin/${JOB_NAME}:${VERSION}
docker push resin/${JOB_NAME}:${ESCAPED_BRANCH_NAME}
docker push resin/${JOB_NAME}:latest

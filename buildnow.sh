#!/bin/bash
#


[[ "$1" != "" ]] && BRANCH="$1" || BRANCH=main
[[ "$BRANCH" == "main" ]] && TAG="latest" || TAG="$BRANCH"
[[ "$ARCHS" == "" ]] && ARCHS="linux/armhf,linux/arm64,linux/amd64"

BASETARGET1=ghcr.io/kx1t
BASETARGET2=kx1t

IMAGE1="$BASETARGET1/$(pwd | sed -n 's|.*/docker-\(.*\)|\1|p'):$TAG"
IMAGE2="$BASETARGET2/$(pwd | sed -n 's|.*/docker-\(.*\)|\1|p'):$TAG"


echo "press enter to start building $IMAGE1 and $IMAGE2 from $BRANCH"
read

starttime="$(date +%s)"
# rebuild the container
set -x
git checkout $BRANCH || exit 2
git pull -a
docker buildx build --compress --push $2 --platform $ARCHS --tag $IMAGE1 .
[[ $? ]] && docker buildx build --compress --push $2 --platform $ARCHS --tag $IMAGE2 .
echo "Total build time: $(( $(date +%s) - starttime )) seconds"

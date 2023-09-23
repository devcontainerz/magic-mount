#!/usr/bin/env sh


echo "Building Container"

docker run -d nginx:latest

echo "Container Built"

docker ps

export CONTAINER_ID=$(docker ps -q)

echo "Container ID: $CONTAINER_ID"
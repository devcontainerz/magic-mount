#!/usr/bin/bash



echo "Building Container"
# docker run -d debian:latest
docker run -d debian sleep 3000
echo "Container Built"
docker ps
CONTAINER_ID=$(docker ps -q)
echo "Container ID: $CONTAINER_ID"
export CONTAINER_ID=$CONTAINER_ID


sleep 1

# #############################################################################################################


/root/magic-mount/examples/install-feature-to-container.sh "$CONTAINER_ID" "/root/magic-mount/examples/features/docker-cli"

# #############################################################################################################


echo "Running docker exec to enter shell"
docker exec -it $CONTAINER_ID /bin/bash

docker container rm $CONTAINER_ID --force


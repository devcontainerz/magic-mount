#!/usr/bin/bash



# #############################################################################################################


echo "Building Container"
docker run -d nginx:latest
echo "Container Built"
docker ps
CONTAINER_ID=$(docker ps -q)
echo "Container ID: $CONTAINER_ID"
export CONTAINER_ID=$CONTAINER_ID


# #############################################################################################################


echo "Container ID: $CONTAINER_ID"
echo "docker exec -d $CONTAINER_ID mkdir -p /mnt/magic"

# #############################################################################################################




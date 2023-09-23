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
docker exec -d $CONTAINER_ID mkdir -p /mnt/magic

# #############################################################################################################

# https://jpetazzo.github.io/2015/01/13/docker-mount-dynamic-volumes/
set -e
CONTAINER=$CONTAINER_ID
HOSTPATH=/root/mnt
CONTPATH=/mnt/magic

REALPATH=$(readlink --canonicalize $HOSTPATH)
FILESYS=$(df -P $REALPATH | tail -n 1 | awk '{print $6}')

while read DEV MOUNT JUNK
do [ $MOUNT = $FILESYS ] && break
done </proc/mounts
[ $MOUNT = $FILESYS ] # Sanity check!

while read A B C SUBROOT MOUNT JUNK
do [ $MOUNT = $FILESYS ] && break
done < /proc/self/mountinfo 
[ $MOUNT = $FILESYS ] # Moar sanity check!

SUBPATH=$(echo $REALPATH | sed s,^$FILESYS,,)
DEVDEC=$(printf "%d %d" $(stat --format "0x%t 0x%T" $DEV))

docker-enter $CONTAINER -- sh -c \
	     "[ -b $DEV ] || mknod --mode 0600 $DEV b $DEVDEC"
docker-enter $CONTAINER -- mkdir /tmpmnt
docker-enter $CONTAINER -- mount $DEV /tmpmnt
docker-enter $CONTAINER -- mkdir -p $CONTPATH
docker-enter $CONTAINER -- mount -o bind /tmpmnt/$SUBROOT/$SUBPATH $CONTPATH
docker-enter $CONTAINER -- umount /tmpmnt
docker-enter $CONTAINER -- rmdir /tmpmnt


# #############################################################################################################


echo "Running docker exec to enter shell"
docker exec -it $CONTAINER_ID -- /bin/bash

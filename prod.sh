#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
	echo 'Usage: ./mount-to-container.sh <container> <hostpath> <containerpath>

This mounts $HOSTPATH into $CONTAINERPATH into the running container $CONTAINER.

'
	exit
fi

cd "$(dirname "$0")"

main() {
	local CONTAINER=$1
	local HOSTPATH=$2
	local CONTPATH=$3

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

	docker-enter $CONTAINER sh -c \
			"[ -b $DEV ] || mknod --mode 0600 $DEV b $DEVDEC"
	docker-enter $CONTAINER mkdir /tmpmnt
	docker-enter $CONTAINER mount $DEV /tmpmnt
	docker-enter $CONTAINER mkdir -p $CONTPATH
	docker-enter $CONTAINER mount -o bind /tmpmnt/$SUBROOT/$SUBPATH $CONTPATH
	docker-enter $CONTAINER umount /tmpmnt
	docker-enter $CONTAINER rmdir /tmpmnt
}


main "$@"

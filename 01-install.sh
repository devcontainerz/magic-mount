#!/usr/bin/env sh

#!/usr/bin/bash

echo "Installing tools…"
apt-get update 
apt-get install -yq util-linux curl wget git jq unzip build-essential gcc make


#  https://github.com/jpetazzo/nsenter/blob/master/importenv.c
cat <<EOF > importenv.c
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>

const int MAX_ENV_SIZE = 1024*1024;
const int MAX_ENV_VARS = 1024;

int main (int argc, char* argv[]) {
	if (argc < 3) {
		printf("Syntax: %s <environ-file> <cmd> [args...]\n", argv[0]);
		exit(1);
	}
	int fd = open(argv[1], O_RDONLY);
	if (-1 == fd) {
		perror("open");
		exit(1);
	}
	char env[MAX_ENV_SIZE+2];
	int env_size = read(fd, env, MAX_ENV_SIZE);
	if (-1 == env_size) {
		perror("read");
		exit(1);
	}
	if (MAX_ENV_SIZE == env_size) {
		printf("WARNING: environment bigger than %d bytes. It has been truncated.\n", MAX_ENV_SIZE);
	}
	char* envp[MAX_ENV_VARS];
	int i;
	char *c;
	for (i=0, c=env; i<MAX_ENV_VARS && *c; i++, c+=strlen(c)+1) {
		envp[i] = c;
	}
	if (i == MAX_ENV_VARS) {
		printf("WARNING: more than %d vars. Some have been clobbered.\n", MAX_ENV_VARS);
	}
	if (-1 == execvpe(argv[2], argv+2, envp)) {
		perror("exec");
		exit(1);
	}
	// Unreachable
	exit(42);
}
EOF

gcc importenv.c -o importenv
install -m 0755 -d importenv /usr/local/bin

rm importenv.c importenv
mkdir -p /root/mnt/test
echo "test" > mnt/test/test.txt



# https://raw.githubusercontent.com/jpetazzo/nsenter/master/docker-enter
cat <<'EOF' > docker-enter
#!/bin/sh

if [ -e $(dirname "$0")/nsenter ]; then
	# with boot2docker, nsenter is not in the PATH but it is in the same folder
	NSENTER=$(dirname "$0")/nsenter
else
	NSENTER=nsenter
fi

if [ -e $(dirname "$0")/importenv ]; then
	# with boot2docker, importenv is not in the PATH but it is in the same folder
	IMPORTENV=$(dirname "$0")/importenv
else
	IMPORTENV=importenv
fi

if [ -z "$1" ]; then
	echo "Usage: `basename "$0"` CONTAINER [COMMAND [ARG]...]"
	echo ""
	echo "Enters the Docker CONTAINER and executes the specified COMMAND."
	echo "If COMMAND is not specified, runs an interactive shell in CONTAINER."
	exit
fi

PID=$(docker inspect --format "{{.State.Pid}}" "$1")
[ -z "$PID" ] && exit 1
shift

if [ "$(id -u)" -ne "0" ]; then
	which sudo > /dev/null
	if [ "$?" -eq "0" ]; then
	  LAZY_SUDO="sudo "
	else
	  echo "Warning: Cannot find sudo; Invoking nsenter as the user $USER." >&2
	fi
fi

ENVIRON="/proc/$PID/environ"

# Prepare nsenter flags
OPTS="--target $PID --mount --uts --ipc --net --pid --"

# env is to clear all host environment variables and set then anew
if [ $# -lt 1 ]; then
	# No arguments, default to `su` which executes the default login shell
	$LAZY_SUDO "$IMPORTENV" "$ENVIRON" "$NSENTER" $OPTS su -m root
else
	# Has command
	# "$@" is magic in bash, and needs to be in the invocation
	$LAZY_SUDO "$IMPORTENV" "$ENVIRON" "$NSENTER" $OPTS "$@"
fi
EOF

cp docker-enter /usr/local/bin
chmod a+x /usr/local/bin/docker-enter

echo "Done installing tools."




# #############################################################################################################

echo "Installing docker"

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Install Docker Engine:
apt-get install -y --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# echo "docker-installed" > /etc/containerous.com/state

echo "Done installing docker"


# #############################################################################################################

# TODO : Check "--" removed (see: https://jpetazzo.github.io/2015/01/13/docker-mount-dynamic-volumes/)
cat <<'EOF' > mount-to-container
#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
    set -o xtrace
fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
	echo 'Usage: ./mount-to-container <container> <hostpath> <containerpath>

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
EOF
install -m 0755 -d mount-to-container /usr/local/bin
rm mount-to-container


# #############################################################################################################



# #############################################################################################################



# #############################################################################################################
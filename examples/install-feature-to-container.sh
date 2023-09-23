#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
if [[ "${TRACE-0}" == "1" ]]; then
	set -o xtrace
fi

if [[ "${1-}" =~ ^-*h(elp)?$ ]]; then
	echo 'Usage: ./mount-to-container.sh <container> <featurepath>

Installs a feature to a running container.

'
	exit
fi

cd "$(dirname "$0")"

main() {
	local CONTAINER=$1
	local FEATUREPATH=$2
	echo "Installing feature ${FEATUREPATH} to container ${CONTAINER}"
	mount-to-container $CONTAINER $FEATUREPATH /featureInstall
	docker exec -d $CONTAINER "/featureInstall/install.sh"

	echo "DONE" > /root/DONE.txt

}


main "$@"

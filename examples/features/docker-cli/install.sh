#!/usr/bin/env bash

echo "INSTALL.sh" >/root/install_sh_success.txt
VERSION="latest"

set -o errexit -o pipefail -o noclobber -o nounset

readonly name='docker'
# [feature options]
# note: see "options" key in devcontainer-feature.json
# @param version - string - format "latest" or "X.Y.Z" i.e. "7.1.2"
readonly version="${VERSION}"

# validate given options
: "${version:?}"

# [os information]
# note: os_id is i.e. "debian" (Debian) or "ubuntu" (Ubuntu)
readonly os_id="$(. /etc/os-release && echo ${ID:?})"
# note: os_codename is i.e. "bookworm" (Debian) or "jammy" (Ubuntu)
readonly os_codename="$(. /etc/os-release && echo ${VERSION_CODENAME:?})"
# note: os_architecture is i.e. "amd64" or "arm64"
readonly os_architecture="$(dpkg --print-architecture)"

readonly apt_key_folder="/etc/apt/keyrings"
readonly apt_key_url='ttps://download.docker.com/linux/debian/gpg'
readonly apt_key_path="${apt_key_folder}/${name}.asc"

readonly apt_repo_path="/etc/apt/sources.list.d/${name}.list"
# example: Debian - URL -> https://download.docker.com/linux/debian
# example: Ubuntu - URL -> https://download.docker.com/linux/ubuntu
readonly apt_repo_url="https://download.docker.com/linux/${os_id}"
readonly apt_repo_host='download.docker.com'
readonly apt_repo_distribution="${os_codename}"
readonly apt_repo_components='stable'

readonly apt_preference_path="/etc/apt/preferences.d/${name}.pref"
# note: pinned packages means packages that can only be installed from given repo above
# note: must be single line string separated by spaces i.e. "mysql-server mysql-client"
# note: use glob syntax to match multiple packages i.e. "msql-server mysql-server-*"
readonly apt_preference_pinned_packages='docker-ce containerd.io docker-ce-cli docker-compose-plugin docker-buildx-plugin'

rm \
  "${apt_key_path}" \
  "${apt_repo_path}" \
  "${apt_preference_path}" \
  || true

apt-get update
apt-get install -yq \
  curl \
  gnupg

install -d \
  -m 755 \
  "${apt_key_folder}"

curl -sL \
 -o "${apt_key_path}" \
 "${apt_key_url}"

# see: https://wiki.debian.org/SourcesList
tee "${apt_repo_path}" << APT_SOURCE
deb [arch=${os_architecture} signed-by=${apt_key_path}] ${apt_repo_url} ${apt_repo_distribution} ${apt_repo_components}
APT_SOURCE

# see: https://wiki.debian.org/AptConfiguration
tee "${apt_preference_path}" << APT_PREFERENCE
Package: ${apt_preference_pinned_packages}
Pin: origin ${apt_repo_host}
Pin-Priority: 1001

Package: ${apt_preference_pinned_packages}
Pin: origin *
Pin-Priority: 1
APT_PREFERENCE

apt-get update

# note: this bock enables installating versions format "latest" or "X.Y.Z" i.e. "7.1.2"
if [ "${version}" == 'latest' ]; then
  apt_packages='docker-ce-cli docker-compose-plugin docker-buildx-plugin'
else
  # note: find the correct package version i.e. "6:7.2.1-1rl1~bookworm1"
  readonly package_version=$(apt-cache madison docker-ce-cli | awk '{ print $3; }' | sort -r | uniq | grep -E "^[0-9]+:(${version})-" | head -1)
  if [ -z "${package_version}" ]; then
    echo "package(s): \"docker-ce-cli\" not found for version \"${version}\""
    exit 1
  fi
  apt_packages="docker-ce-cli=${package_version}"
fi

apt-get install -qq \
  -o 'Debug::pkgProblemResolver=true' \
  -o 'Debug::pkgAcquire::Worker=1' \
  --no-install-recommends \
  --no-install-suggests \
  --allow-downgrades \
    ${apt_packages}
#!/usr/bin/env bash

echo "starship" > /root/starship_install.txt



set -o errexit -o pipefail -o noclobber -o nounset

# note: only install rsync if not already vailable
if ! command -v curl >/dev/null 2>&1; then
  apt-get update
  apt-get install -qq \
    -o 'Debug::pkgProblemResolver=true' \
    -o 'Debug::pkgAcquire::Worker=1' \
    --no-install-recommends \
    --no-install-suggests \
      curl ca-certificates
fi

apt-get install ca-certificates

readonly version="${VERSION:-1.13.1}"
readonly file="https://github.com/starship/starship/releases/download/v${version}/starship-x86_64-unknown-linux-gnu.tar.gz"

echo '=== Download starship prompt binary from GitHub Releases to "/usr/local/bin/starship"'
echo "=== --- Download from: ${file}"
curl \
  -sL\
  -o- \
  ${file} \
| tar \
  -xz \
  -C /usr/local/bin/ \
  starship


# echo '=== Add starship init to "~/.bashrc"'
# echo 'source <(starship init $SHELL)' | >/dev/null tee -a "${cypress__HOME}/.bashrc"


# echo '=== Install "starship" config file to "~/.config/starship.toml"'
# install \
#   --mode='0660' \
#   --owner="${cypress__user_name}" \
#   --group="${cypress__group_name}" \
#     "${build_context_folder}/config/starship/starship.toml" \
#     "${cypress__HOME}/.config/starship.toml"
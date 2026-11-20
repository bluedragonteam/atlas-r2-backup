#!/usr/bin/env bash
# Install MongoDB Database Tools and age, pinned to exact versions and checked against SHA-256 sums.
set -euo pipefail

TOOLS_VERSION=100.10.0
AGE_VERSION=v1.2.1
AGE_SHA256=7df45a6cc87d4da11cc03a539a7470c15b1041ab2b396af088fe9990f7c79d50

. /etc/os-release
case "${VERSION_ID}" in
  22.04) DISTRO=ubuntu2204; TOOLS_SHA256=59ba7715eff51602321cfebd8bb774fbae9bcf320b19424ee571ac642ab17377 ;;
  24.04) DISTRO=ubuntu2404; TOOLS_SHA256=cfde5981270d982773b56975260918b929e9acef44861cb6c300422324aa3e75 ;;
  *) echo "::error::Unsupported runner OS ${PRETTY_NAME:-unknown}; use ubuntu-22.04 or ubuntu-24.04"; exit 1 ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if ! command -v mongodump > /dev/null || ! mongodump --version | grep -q "${TOOLS_VERSION}"; then
  curl -fsSL -o "$tmp/tools.deb" \
    "https://fastdl.mongodb.org/tools/db/mongodb-database-tools-${DISTRO}-x86_64-${TOOLS_VERSION}.deb"
  echo "${TOOLS_SHA256}  $tmp/tools.deb" | sha256sum -c --quiet -
  sudo apt-get install -y -qq "$tmp/tools.deb" > /dev/null
fi

if ! command -v age > /dev/null; then
  curl -fsSL -o "$tmp/age.tgz" \
    "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz"
  echo "${AGE_SHA256}  $tmp/age.tgz" | sha256sum -c --quiet -
  tar -xzf "$tmp/age.tgz" -C "$tmp"
  sudo install "$tmp/age/age" "$tmp/age/age-keygen" /usr/local/bin/
fi

echo "mongodump $(mongodump --version | head -n 1 | awk '{print $NF}'), age $(age --version)"

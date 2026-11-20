#!/usr/bin/env bash
# Decrypt a backup made by atlas-r2-backup and restore it with mongorestore.
# Usage: restore.sh <backup.archive.gz.age> <age-identity-file> <target-mongodb-uri> [extra mongorestore args...]
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 <backup.archive.gz.age> <age-identity-file> <target-mongodb-uri> [mongorestore args...]" >&2
  exit 2
fi
backup=$1 identity=$2 target=$3
shift 3

for tool in age mongorestore; do
  command -v "$tool" > /dev/null || { echo "$tool is not installed" >&2; exit 1; }
done

archive=$(mktemp)
trap 'rm -f "$archive"' EXIT

age -d -i "$identity" -o "$archive" "$backup"
mongorestore --uri="$target" --archive="$archive" --gzip "$@"

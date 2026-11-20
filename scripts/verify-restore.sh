#!/usr/bin/env bash
# Restore the dump into a throwaway MongoDB container and fail unless documents restore cleanly.
# A backup that has never been restored is only a hope.
set -euo pipefail

: "${WORK:?}" "${MONGO_IMAGE:?}"
name="backup-verify-$$"
port=27099

docker run -d --rm --name "$name" -p "127.0.0.1:${port}:27017" "$MONGO_IMAGE" > /dev/null
trap 'docker stop "$name" > /dev/null 2>&1 || true' EXIT

for _ in $(seq 1 60); do
  docker exec "$name" mongosh --quiet --eval 'db.runCommand({ ping: 1 }).ok' > /dev/null 2>&1 && break
  sleep 1
done

mongorestore --uri="mongodb://127.0.0.1:${port}" --archive="$WORK/db.archive" --gzip 2> "$WORK/restore.log" || {
  cat "$WORK/restore.log"
  exit 1
}
summary=$(grep -E 'document\(s\) restored successfully' "$WORK/restore.log" | tail -n 1)
echo "$summary"

restored=$(grep -oE '[0-9]+ document\(s\) restored successfully' <<< "$summary" | grep -oE '^[0-9]+' || true)
failed=$(grep -oE '[0-9]+ document\(s\) failed to restore' <<< "$summary" | grep -oE '^[0-9]+' || true)
if [ -z "$summary" ] || [ "${restored:-0}" -eq 0 ] || [ "${failed:-1}" -ne 0 ]; then
  echo "::error::Restore check failed: ${summary:-no summary from mongorestore}"
  exit 1
fi
echo "documents=$restored" >> "$GITHUB_OUTPUT"
